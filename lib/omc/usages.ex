defmodule Omc.Usages do
  @moduledoc """
  Collects all functionalities related to calculating user's acc usages by providing required
  changesets to:
    - update a `ledger`. 
    - adding coresponding `ledger_tx`
    - renewing (updating+inserting) `server_user_acc` as need
  It is better to not persist any changeset if possible, and instead use
  calculated values (applying changeset in memory) as much as possible; Because most of the times 
  users wants to see their remaning credit using this module and somtimes on some periodic calls 
  system wants to see usage date for persistance.
  """

  alias Omc.Servers
  alias Omc.Usages.UsageItem
  alias Omc.ServerAccUsers
  alias Omc.Servers.ServerAccUser
  alias Omc.Ledgers
  alias Omc.Ledgers.Ledger
  alias Omc.Usages.Usage
  alias Omc.Repo
  import Ecto.Query

  # Minimum duration in seconds which is considered in usage calculations
  @minimum_considerable_usasge_in_seconds 60 * 60

  defmodule UsageState do
    @moduledoc false

    defstruct usages: [],
              ledgers: [],
              changesets: []

    def add_usage_ledger_tx(
          %__MODULE__{} = state,
          %Money{} = money,
          %{} = usage_item_attrs
        ) do
      state
      |> add_changesets(money, usage_item_attrs)
      |> apply_usage_changeset()
      |> apply_ledger_changeset()
    end

    defp add_changesets(%__MODULE__{} = state, money, usage_item_attrs) do
      state
      |> add_item(
        :changesets,
        Ledgers.ledger_update_changeset(%{
          ledger: ledger_by_currency(state, money.currency),
          context: :usage,
          context_id: -1,
          amount: money.amount,
          type: :debit
        })
        |> Map.put(:usage_item_changeset, UsageItem.create_changeset(usage_item_attrs))
      )
    end

    defp apply_usage_changeset(%__MODULE__{} = state) do
      %{usage_item_changeset: changeset} = state.changesets |> List.last()

      state
      |> Map.replace(
        :usages,
        state.usages
        |> Enum.map(fn usage ->
          if usage.id == changeset.changes.usage_id do
            usage
            |> Map.replace(
              :usage_items,
              usage.usage_items ++ [Ecto.Changeset.apply_changes(changeset)]
            )
          else
            usage
          end
        end)
      )
    end

    # defp apply_ledger_tx_changeset(%__MODULE__{} = state) do
    #   %{ledger_tx_changeset: changeset} = state.changesets |> List.last()
    #
    #   state
    #   |> apply_changeset(:ledger_tx_changesets, changeset)
    # end

    defp apply_ledger_changeset(%__MODULE__{} = state) do
      %{ledger_changeset: changeset} = state.changesets |> List.last()

      state
      |> apply_changeset(:ledgers, changeset)
    end

    defp add_item(%__MODULE__{} = state, member, item) do
      state
      |> Map.replace(member, Map.get(state, member) ++ [item])
    end

    defp apply_changeset(%__MODULE__{} = state, member, changeset) do
      state
      |> Map.replace(
        member,
        Map.get(state, member)
        |> Enum.map(fn item ->
          if item.id == changeset.data.id do
            Ecto.Changeset.apply_changes(changeset)
          else
            item
          end
        end)
      )
    end

    defp ledger_by_currency(%__MODULE__{} = state, currency) do
      state.ledgers
      |> Enum.find(&(&1.currency == currency))
    end
  end

  @doc """
  Returns current usage state (without persisting anything) in terms of current computed last state of 
  `Ledger`s and companied by `LedgerTx`s, `ServerAccUser`s, and their corresponding changesets.
  """
  @spec usage_state(%{user_type: atom(), user_id: binary()}) :: UsageState.t()
  def usage_state(%{user_type: _user_type, user_id: _user_id} = attrs) do
    %UsageState{
      usages: list_active_usages(attrs),
      ledgers: Ledgers.get_ledgers(attrs)
    }
    |> __usage_state__()
  end

  @doc false
  def __usage_state__(%UsageState{} = state) do
    case first_duration_usage(state.usages) do
      nil ->
        state

      usage ->
        case first_oldest_no_zero_credit_ledger(state.ledgers) do
          # No credit, going to make last used ledger's credit negetive
          nil ->
            first_newset_used_credit(state.ledgers)
            |> use_credit(usage, state, :duration)
            |> __usage_state__()

          # Some credit, going to use it.
          ledger ->
            ledger
            |> use_credit(usage, state, :duration)
            |> __usage_state__()
        end
    end
  end

  @doc false
  def use_credit(%Ledger{} = ledger, %Usage{} = usage, %UsageState{} = state, :duration) do
    (amount = calc_duration_usage(usage, ledger.currency))
    |> Money.compare(Money.new(ledger.credit, ledger.currency))
    |> case do
      # usage amount is greater than credit
      1 ->
        # TODO
        raise "not supported yet"

      # usage amount is less than or equal credit
      _ ->
        usage_item_attrs = %{
          type: :duration,
          started_at: usage_start_time(usage),
          ended_at: now(),
          usage_id: usage.id
        }

        UsageState.add_usage_ledger_tx(state, amount, usage_item_attrs)
    end
  end

  @doc false
  def first_newset_used_credit([%Ledger{}] = ledgers) do
    ledgers
    |> Enum.filter(&(&1.updated_at != nil))
    |> Enum.sort(&(NaiveDateTime.compare(&1.updated_at, &2.updated_at) == :gt))
    |> List.first()
  end

  @doc false
  def first_duration_usage(usages) do
    usages
    |> Enum.filter(fn usage ->
      now()
      |> NaiveDateTime.diff(usage_start_time(usage))
      |> Kernel.>=(@minimum_considerable_usasge_in_seconds)
    end)
    |> List.first()
  end

  @doc false
  def usage_start_time(%Usage{} = usage) do
    case usage.usage_items |> List.last() do
      nil ->
        usage.started_at

      last_usage_item ->
        last_usage_item.ended_at
    end
  end

  @spec calc_duration_usage(%Usage{}, atom()) :: Money.t()
  def calc_duration_usage(%Usage{} = usage, currency) do
    calc_duration_usage(
      usage,
      currency,
      NaiveDateTime.utc_now()
      |> NaiveDateTime.truncate(:second)
      |> NaiveDateTime.diff(usage_start_time(usage))
    )
  end

  @doc false
  def calc_duration_usage(%Usage{} = usage, currency, %UsageItem{type: :duration} = usage_item) do
    calc_duration_usage(
      usage,
      currency,
      usage_item.ended_at
      |> NaiveDateTime.diff(usage_item.started_at)
    )
  end

  def calc_duration_usage(%Usage{} = usage, currency, duration_in_seconds)
      when duration_in_seconds > 0 do
    duration_in_seconds
    |> Decimal.new()
    |> Decimal.mult(price(usage, currency) |> Money.to_decimal())
    |> Decimal.div(usage.price_plan.duration_days * 24 * 60 * 60)
    |> Money.parse(currency)
    |> then(fn {:ok, money} -> money end)
  end

  def calc_duration_usage(%Usage{} = _usage, currency, duration_in_seconds)
      when duration_in_seconds <= 0 do
    Money.new(0, currency)
  end

  # def calc_usage_uptime(%Usage{} = usage, %Money{} = money) do
  #   # TODO
  #   now()
  # end

  @doc false
  def price(%Usage{} = usage, currency) do
    usage.price_plan.prices
    |> Enum.find(fn money -> money.currency == currency end)
  end

  @doc false
  def first_oldest_no_zero_credit_ledger(ledgers) do
    case ledgers
         |> Enum.filter(&(&1.updated_at == nil and &1.credit > 0))
         |> Enum.sort(&(NaiveDateTime.compare(&1.inserted_at, &2.inserted_at) == :lt))
         |> List.first() do
      nil ->
        ledgers
        |> Enum.filter(&(&1.updated_at != nil and &1.credit > 0))
        |> Enum.sort(&(NaiveDateTime.compare(&1.updated_at, &2.updated_at) == :lt))
        |> List.first()

      not_updated ->
        not_updated
    end
  end

  def minimum_considerable_usasge_in_seconds, do: @minimum_considerable_usasge_in_seconds

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

  defp now() do
    NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
  end

  @doc """
  Creates new `Usage` to indicate usage start.
  From this on, it is possible to calculate duration or volume usage.
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
      started_at: now(),
      price_plan: Servers.get_default_server_price_plan(sau.server_acc_id)
    }
    |> Usage.create_changeset()
    |> Repo.insert()
  end
end
