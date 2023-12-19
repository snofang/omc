defmodule Omc.Usages do
  require Logger
  alias Omc.Usages.UsageItem
  alias Omc.Ledgers.LedgerTx
  alias Ecto.Repo
  alias Omc.Servers
  alias Omc.ServerAccUsers
  alias Omc.Servers.ServerAccUser
  alias Omc.Ledgers
  alias Omc.Usages.{Usage, UsageState, UsageLineItem}
  alias Omc.Repo
  alias Omc.Ledgers.Ledger
  import Ecto.Query

  @doc """
  Returns current usage state (without persisting anything) in terms of current computed last `UsageState`
  """
  @spec get_user_usage_state(%{user_type: atom(), user_id: binary()}) :: %UsageState{}
  def get_user_usage_state(%{user_type: _user_type, user_id: _user_id} = attrs) do
    %UsageState{
      usages: get_active_usages(attrs),
      ledgers: Ledgers.get_ledgers(attrs)
    }
    |> UsageState.compute()
  end

  # TODO: add some tests for this function(currently just tested via end_usage_only/1)
  @doc """
  Gets current usage state (without persisting anything) of specified active `server_acc_user_id`.
  """
  @spec get_acc_usage_state(server_acc_user_id :: integer()) :: %UsageState{}
  def get_acc_usage_state(server_acc_user_id) do
    sau = ServerAccUsers.get_server_acc_user(server_acc_user_id)

    %UsageState{
      # TODO: add a test case to cover non existance active usage
      usages: if(u = get_active_usage_by_sau_id(sau.id), do: [u], else: []),
      ledgers: Ledgers.get_ledgers(ServerAccUser.user_attrs(sau))
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
      |> get_user_usage_state()
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
        money: Money.new(ledger_tx_changeset.changes.amount, ledger_changeset.data.currency)
      }
      |> Ledgers.create_ledger_tx!()
      |> then(&{:ok, &1})
    end)
    |> Repo.transaction()
  end

  defp get_active_usages(%{user_type: user_type, user_id: user_id}) do
    from(u in usages_query(),
      join: sau in ServerAccUser,
      on: sau.id == u.server_acc_user_id,
      where: sau.user_type == ^user_type and sau.user_id == ^user_id,
      where: is_nil(u.ended_at)
    )
    |> Repo.all()
  end

  defp usages_query() do
    from(u in Usage,
      join: pp in assoc(u, :price_plan),
      left_join: ui in assoc(u, :usage_items),
      order_by: [asc: u.id, asc: ui.id],
      preload: [usage_items: ui],
      preload: [price_plan: pp]
    )
  end

  @doc false
  def get_active_usage_by_sau_id(sau_id) do
    from(u in usages_query(),
      where: u.server_acc_user_id == ^sau_id,
      where: is_nil(u.ended_at)
    )
    |> Repo.one()
  end

  @doc """
  Creates a new `Usage` `started_at` now and following on, it'll be possible to calculate `sau` usages.
  """
  @spec start_usage(%ServerAccUser{}) ::
          {:ok, %{usage: %Usage{}, server_acc_user: %ServerAccUser{}}} | {:error, term()}
  def start_usage(%ServerAccUser{} = sau) do
    case Ecto.Multi.new()
         |> Ecto.Multi.run(:server_acc_user, fn _repo, _changes ->
           ServerAccUsers.start_server_acc_user(sau)
         end)
         |> Ecto.Multi.run(:usage, fn _repo, %{server_acc_user: sau} ->
           create_usage(sau)
         end)
         |> Repo.transaction() do
      {:error, _failed_operation, failed_value, _changes_so_far} -> {:error, failed_value}
      other -> other
    end
  end

  @doc """
  Finds any available `ServerAcc` and starts a `Usage` for given `user`
  ## Options
    * `:server_tag`
    * `:price_plan_id`
  """
  def start_usage(
        user = %{user_id: _, user_type: _},
        opts \\ []
      ) do
    case Ecto.Multi.new()
         |> Ecto.Multi.run(:allocate_sau, fn _repo, _changes ->
           ServerAccUsers.allocate_new_server_acc_user(user, opts)
         end)
         |> Ecto.Multi.run(:start_usage, fn _repo, %{allocate_sau: sau} ->
           start_usage(sau)
         end)
         |> Repo.transaction() do
      {:ok, %{start_usage: start_usage}} -> {:ok, start_usage}
      {:error, _failed_operation, failed_value, _changes_so_far} -> {:error, failed_value}
    end
  end

  defp create_usage(%ServerAccUser{} = sau) do
    %{
      server_acc_user_id: sau.id,
      started_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
      price_plan_id: Servers.get_default_server_price_plan(sau.server_acc_id) |> then(& &1.id)
    }
    |> Usage.create_changeset()
    |> Repo.insert()
  end

  @doc """
  Ends `usage` by setting its `ended_at` to current `NaiveDateTime` and:
  - Persists all of its `UsageState` chanesets.
  - Ends its `ServerAccUser`.
  """
  @spec end_usage(%Usage{}) ::
          {:ok,
           %{
             usage_and_state: %{usage: %Usage{}, state: %UsageState{}},
             server_acc_user: %ServerAccUser{}
           }}
          | {:error, Ecto.Multi.name(), any, %{required(Ecto.Multi.name()) => any}}
  def end_usage(%Usage{} = usage) do
    Ecto.Multi.new()
    |> Ecto.Multi.run(:usage_and_state, fn _repo, _changes -> end_usage_only(usage) end)
    |> Ecto.Multi.run(:server_acc_user, fn _repo, _changes ->
      ServerAccUsers.get_server_acc_user(usage.server_acc_user_id)
      |> ServerAccUsers.end_server_acc_user()
    end)
    |> Repo.transaction()
  end

  # Ends `usage` without affecting its `ServerAccUser`.
  defp end_usage_only(%Usage{} = usage) do
    usage_state = get_acc_usage_state(usage.server_acc_user_id)

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
      |> end_usage()
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

    from(usage in usages_query(),
      where: is_nil(usage.ended_at),
      join: sau in ServerAccUser,
      on: sau.id == usage.server_acc_user_id,
      join: ledger in subquery(ledger_sum),
      on: ledger.user_id == sau.user_id and ledger.user_type == sau.user_type,
      where: ledger.credit_sum <= 0,
      select: usage,
      limit: ^limit,
      offset: ^((page - 1) * limit)
    )
    |> Repo.all()
  end

  @doc """
  Lists usages which their price duration has expired. 
  """
  def get_active_expired_usages(page \\ 1, limit \\ 10) when page > 0 and limit > 0 do
    from([u, pp] in usages_query(),
      where: is_nil(u.ended_at) and u.started_at <= ago(pp.duration, "second"),
      limit: ^limit,
      offset: ^((page - 1) * limit)
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

  @doc """
  Gets all `UsageLineItem`s of specified `server_acc_user_id` upto now.
  """
  @spec get_acc_usages_line_items(server_acc_user_id :: integer()) :: [%UsageLineItem{}]
  def get_acc_usages_line_items(server_acc_user_id) do
    live_usage_line_items =
      server_acc_user_id
      |> get_acc_usage_state()
      |> UsageLineItem.usage_state_usage_line_items()

    stored_usage_line_items =
      server_acc_user_id
      |> list_stored_acc_usages_line_items()

    stored_usage_line_items ++ live_usage_line_items
  end

  @spec list_stored_acc_usages_line_items(server_acc_user_id :: integer()) :: [%UsageLineItem{}]
  def list_stored_acc_usages_line_items(server_acc_user_id) do
    from(u in subquery(from(u in Usage, where: u.server_acc_user_id == ^server_acc_user_id)),
      join: ui in UsageItem,
      on: u.id == ui.usage_id,
      join: tx in LedgerTx,
      on: tx.context_id == ui.id,
      where: tx.context == :usage,
      join: l in Ledger,
      on: l.id == tx.ledger_id,
      order_by: [asc: ui.id],
      select: %UsageLineItem{
        usage_item_id: ui.id,
        started_at: ui.started_at,
        ended_at: ui.ended_at,
        amount: tx.amount,
        currency: l.currency
      }
    )
    |> Repo.all()
  end
end
