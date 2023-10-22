defmodule Omc.Usages do
  require Logger
  alias Ecto.Repo
  alias Omc.Servers
  alias Omc.Usages.UsageItem
  alias Omc.ServerAccUsers
  alias Omc.Servers.ServerAccUser
  alias Omc.Ledgers
  alias Omc.Usages.{Usage, UsageState}
  alias Omc.Repo
  alias Omc.Ledgers.Ledger
  import Ecto.Query

  @doc """
  Returns current usage state (without persisting anything) in terms of current computed last `UsageState`
  """
  @spec get_usage_state(%{user_type: atom(), user_id: binary()}) :: UsageState.t()
  def get_usage_state(%{user_type: _user_type, user_id: _user_id} = attrs) do
    %UsageState{
      usages: list_active_usages(attrs),
      ledgers: Ledgers.get_ledgers(attrs)
    }
    |> UsageState.compute()
  end

  @doc """
  Persists changesets of a computed `UserState`.
    
  By default only final changeset are presisted; final changesets are those which 
  caused a ledger's credit to be non-positive. Returns same `UsageState` intact
    
  ## Options 
    - `:all` If true, then all changeset are persisted; It means all computed `UsageItem`(s)
      along their related ledger updates are persisted.
      default value is false
  """
  def persist_usage_state!(%UsageState{} = usage_state, opts \\ []) do
    usage_state.ledgers
    |> Enum.filter(fn ledger -> ledger.credit <= 0 or Keyword.get(opts, :all, false) end)
    |> Enum.each(fn ledger ->
      UsageState.changesets_of_ledger(usage_state, ledger)
      |> Enum.each(fn changeset -> {:ok, _} = persist_usage_state_changeset(changeset) end)
    end)

    usage_state
  end

  @doc """
  Loops on every user which have active `Usage`(s), compute their `UsageState` and persist them.
  Note: this is a time consuming process and mostly intended to run on daily schedules or so.
  """
  def update_usage_states(page \\ 1, batch_size \\ 10) do
    (users = get_active_users(page, batch_size))
    |> Enum.each(fn user_attrs ->
      user_attrs
      |> get_usage_state()
      |> persist_usage_state!()
    end)

    if users |> length() > 0, do: update_usage_states(page + 1, batch_size)
  end

  @doc """
  Lists users which have active running usage(s) with paging.
  """
  @spec get_active_users(pos_integer(), pos_integer()) :: [
          %{user_type: atom(), user_id: binary()}
        ]
  def get_active_users(page \\ 1, limit \\ 10) when page > 0 and limit > 0 do
    from(sau in ServerAccUser,
      join: usage in Usage,
      on: usage.server_acc_user_id == sau.id,
      where: is_nil(usage.ended_at),
      distinct: true,
      select: %{user_type: sau.user_type, user_id: sau.user_id},
      limit: ^limit,
      offset: ^((page - 1) * limit)
    )
    |> Repo.all()
  end

  defp persist_usage_state_changeset(%{
         ledger_changeset: ledger_changeset,
         ledger_tx_changeset: ledger_tx_changeset,
         usage_item_changeset: usage_item_changeset
       }) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:usage_item, usage_item_changeset)
    |> Ecto.Multi.run(:ledger, fn _repo, %{usage_item: usage_item} ->
      # TODO: this is messy; Ledgers should expose a function to persist changesets.
      %{
        user_type: ledger_changeset.data.user_type,
        user_id: ledger_changeset.data.user_id,
        context: :usage,
        context_id: usage_item.id,
        money: Money.new(ledger_tx_changeset.changes.amount, ledger_changeset.data.currency),
        type: :debit
      }
      |> Ledgers.create_ledger_tx!()
      |> then(&{:ok, &1})
    end)
    |> Repo.transaction()
  end

  # def restart_usage(%ServerAccUser{} = sau) do
  #   Ecto.Multi.new()
  #   |> Ecto.Multi.run(:server_acc_user_end, fn _repo, _changes ->
  #     ServerAccUsers.end_server_acc_user()
  #   end)
  #
  #   # |> Ecto.Multi.run(:server_acc_user_start, fn _repo, _changes ->)
  # end

  # TODO: Optimize via inner query to fetch only the last usage item
  defp list_active_usages(%{user_type: _, user_id: _} = attrs) do
    server_acc_users = ServerAccUsers.get_server_acc_users_in_use(attrs)

    usage_items = from(ui in UsageItem, order_by: [asc: ui.id])

    from(u in Usage,
      where:
        u.server_acc_user_id in ^(server_acc_users |> Enum.map(&Map.get(&1, :id))) and
          is_nil(u.ended_at),
      preload: [usage_items: ^usage_items]
    )
    |> Repo.all()
  end

  @doc """
  Creates a new `Usage` `started_at` now and following on, it'll be possible to calculate `sau` usages.
  """
  @spec start_usage!(%ServerAccUser{}) :: %{usage: %Usage{}, server_acc_user: %ServerAccUser{}}
  def start_usage!(%ServerAccUser{} = sau) do
    {:ok, %{sau_started: sau_started, usage_started: usage_started}} =
      Ecto.Multi.new()
      |> Ecto.Multi.run(:sau_started, fn _repo, _changes ->
        ServerAccUsers.start_server_acc_user(sau)
      end)
      |> Ecto.Multi.run(:usage_started, fn _repo, %{sau_started: sau_started} ->
        create_usage(sau_started)
      end)
      |> Repo.transaction()

    %{usage: usage_started |> Repo.preload(:usage_items), server_acc_user: sau_started}
  end

  defp create_usage(%ServerAccUser{} = sau) do
    %{
      server_acc_user_id: sau.id,
      started_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
      price_plan: Servers.get_default_server_price_plan(sau.server_acc_id)
    }
    |> Usage.create_changeset()
    |> Repo.insert()
  end

  @doc """
  Ends `usage` by setting its `ended_at` to current `NaiveDateTime` and:
  - Persists all of its `UsageState` chanesets.
  - Ends its `ServerAccUser`.
  """
  def end_usage!(%Usage{} = usage) do
    {:ok, %{end_usage_only: %{usage: usage}}} =
      Ecto.Multi.new()
      |> Ecto.Multi.run(:end_usage_only, fn _repo, _changes -> end_usage_only(usage) end)
      |> Ecto.Multi.run(:end_server_acc_user, fn _repo, _changes ->
        ServerAccUsers.get_server_acc_user(usage.server_acc_user_id)
        |> ServerAccUsers.end_server_acc_user()
      end)
      |> Repo.transaction()

    usage
  end

  # Ends `usage` without affecting its `ServerAccUser`.
  defp end_usage_only(%Usage{} = usage) do
    sau = ServerAccUsers.get_server_acc_user(usage.server_acc_user_id)
    # Computing UsageState just for one usage
    usage_state =
      %UsageState{
        usages: [usage],
        ledgers: Ledgers.get_ledgers(ServerAccUser.user_attrs(sau))
      }
      |> UsageState.compute()

    Ecto.Multi.new()
    |> Ecto.Multi.run(:usage_state, fn _repo, _changes ->
      persist_usage_state!(usage_state, all: true)
      {:ok, usage_state}
    end)
    |> Ecto.Multi.update(:usage, Usage.end_changeset(usage))
    |> Repo.transaction()
  end

  @doc """
  Ends no-credit usages.
    
  Note: this is a time consuming process and mostly intended to run on a daily schedule or so.
  """
  def end_usages_with_no_credit(page \\ 1, batch_size \\ 10) do
    (usages = get_active_no_credit_usages(page, batch_size))
    |> Enum.each(fn usage ->
      usage
      |> end_usage!()
    end)

    if usages |> length() > 0, do: end_usages_with_no_credit(page + 1, batch_size)
  end

  @spec get_active_no_credit_usages(pos_integer(), pos_integer()) :: [
          %{user_type: atom(), user_id: binary()}
        ]
  def get_active_no_credit_usages(page \\ 1, limit \\ 10) when page > 0 and limit > 0 do
    ledger_sum =
      from(ledger in Ledger,
        group_by: [ledger.user_id, ledger.user_type],
        select: %{
          user_id: ledger.user_id,
          user_type: ledger.user_type,
          credit_sum: sum(ledger.credit)
        }
      )

    from(usage in Usage,
      where: is_nil(usage.ended_at),
      join: sau in ServerAccUser,
      on: sau.id == usage.server_acc_user_id,
      join: ledger in subquery(ledger_sum),
      on: ledger.user_id == sau.user_id and ledger.user_type == sau.user_type,
      where: ledger.credit_sum <= 0,
      select: usage,
      limit: ^limit,
      offset: ^((page - 1) * limit),
      preload: :usage_items
    )
    |> Repo.all()
  end

  @doc """
  Lists usages which their price duration has expired. 
  """
  def get_active_expired_usages(page \\ 1, limit \\ 10) when page > 0 and limit > 0 do
    # TODO: to investigate the gin index effectiveness for this 
    from(u in Usage,
      where: is_nil(u.ended_at) and u.started_at <= ago(u.price_plan["duration"], "second"),
      limit: ^limit,
      offset: ^((page - 1) * limit),
      preload: :usage_items
    )
    |> Repo.all()
  end

  @doc """
  Ends `usage` and creates new one starting now and having fresh price plan copied from 
  related server.
  """
  # TODO: The new price plan should be similar; having same `duration`, `max_volume` as the old one. And if 
  # nothing similar found, the first available price should be selected. 
  def renew_usage(%Usage{} = usage) do
    Ecto.Multi.new()
    |> Ecto.Multi.run(:usage_old, fn _repo, _changes -> end_usage_only(usage) end)
    |> Ecto.Multi.run(:usage, fn _repo, _changes ->
      ServerAccUsers.get_server_acc_user(usage.server_acc_user_id)
      |> create_usage()
    end)
    |> Repo.transaction()
  end

  @doc """
  Renews 
  """
  def renew_usages_expired(page \\ 1, limit \\ 1) do
    (usages = get_active_expired_usages(page, limit))
    |> Enum.each(&renew_usage/1)

    if usages |> length() > 0, do: renew_usages_expired()
  end

  @doc """
  Updates usages calling the followings in sequence:
    - update_usage_states/0: to update ledgers as required.
    - end_usages_with_no_credit/0
    - renew_usages_expired/0

  Note: this is a time consuming proces and intended to run on a schedule.
  """
  def update_usages() do
    Logger.info("-- update usages --")
    update_usage_states()
    end_usages_with_no_credit()
    renew_usages_expired()
  end
end
