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

  alias Omc.Servers.ServerAccUser
  alias Omc.ServerAccUsers
  alias Omc.Ledgers
  alias Omc.Ledgers.Ledger

  # Note: server price is fixed for 30 days
  @pricing_duration_in_seconds 30 * 24 * 60 * 60
  # Minimum duration in seconds which is considered in usage calculations
  @minimum_considerable_usasge_in_seconds 60 * 60

  defmodule UsageState do
    @moduledoc false
    
    defstruct ledgers: [],
              server_acc_users: [],
              ledger_changesets: [],
              ledger_tx_changesets: [],
              server_acc_user_changesets: [],
              server_acc_user_create_changesets: []

    def add_usage_tx(
          %__MODULE__{} = state,
          %Ledger{} = ledger,
          %Money{} = money,
          %ServerAccUser{} = sau
        ) do
      Ledgers.ledger_update_changeset(%{
        ledger: ledger,
        context: :usage,
        context_id: sau.id,
        amount: money.amount,
        type: :debit
      })
      |> then(fn %{ledger_changeset: ledger_changeset, ledger_tx_changeset: ledger_tx_changeset} ->
        state
        |> add_item(:ledger_changesets, ledger_changeset)
        |> apply_changeset(:ledgers, ledger_changeset)
        |> add_item(:ledger_tx_changesets, ledger_tx_changeset)
        |> server_acc_user_end_start(sau)
      end)
    end

    defp server_acc_user_end_start(state, %ServerAccUser{} = sau) do
      sau_end_changeset = ServerAccUser.end_changeset(sau)

      sau_new =
        server_acc_user_create_changeset(sau)
        |> Ecto.Changeset.apply_changes()
        |> Map.replace(:id, System.unique_integer([:positive]))
      sau_new_start_changeset = ServerAccUser.start_changeset(sau_new)

      state
      # ending exising sau
      |> add_item(:server_acc_user_changesets, sau_end_changeset)
      |> apply_changeset(:server_acc_users, sau_end_changeset)
      # adding new sau
      |> add_item(:server_acc_user_create_changesets, server_acc_user_create_changeset(sau))
      |> add_item(:server_acc_users, sau_new)
      # staring new sau
      |> add_item(:server_acc_user_changesets, sau_new_start_changeset)
      |> apply_changeset(:server_acc_users, sau_new_start_changeset)
    end

    defp server_acc_user_create_changeset(sau) do
      ServerAccUser.create_chageset(%{
        user_type: sau.user_type,
        user_id: sau.user_id,
        server_acc_id: sau.server_acc_id,
        prices: sau.prices
      })
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
  end

  @doc """
  Returns current usage state (without persisting anything) in terms of current computed last state of 
  `Ledger`s and companied by `LedgerTx`s, `ServerAccUser`s, and their corresponding changesets.
  """
  @spec usage_state(%{user_type: atom(), user_id: binary()}) :: UsageState.t()
  def usage_state(%{user_type: _user_type, user_id: _user_id} = attrs) do
    %UsageState{
      ledgers: Ledgers.get_ledgers(attrs),
      server_acc_users: ServerAccUsers.get_server_acc_users_in_use(attrs)
    }
    |> __usage_state__()
  end

  @doc false
  def __usage_state__(%UsageState{} = state) do
    case first_in_use_server_acc_user(state.server_acc_users) do
      nil ->
        state

      sau ->
        case first_oldest_no_zero_credit_ledger(state.ledgers) do
          # No credit, going to make last used ledger's credit negetive
          nil ->
            first_newset_used_credit(state.ledgers)
            |> use_credit(sau, state)
            |> __usage_state__()

          # Some credit, going to use it.
          ledger ->
            ledger
            |> use_credit(sau, state)
            |> __usage_state__()
        end
    end
  end

  @doc false
  def use_credit(%Ledger{} = ledger, %ServerAccUser{} = sau, %UsageState{} = state) do
    (amount = calc_usage(sau, ledger.currency))
    |> Money.compare(Money.new(ledger.credit, ledger.currency))
    |> case do
      # usage amount is greater than credit
      1 ->
        # TODO
        raise "not supported yet"

      # usage amount is less than or equal credit
      _ ->
        state
        |> UsageState.add_usage_tx(ledger, amount, sau)
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
  @spec first_in_use_server_acc_user([%ServerAccUser{}]) :: %ServerAccUser{} | nil
  def first_in_use_server_acc_user(server_acc_users) do
    server_acc_users
    |> Enum.filter(
      &(&1.started_at != nil and &1.ended_at == nil and
          NaiveDateTime.utc_now()
          |> NaiveDateTime.truncate(:second)
          |> NaiveDateTime.diff(&1.started_at) >= @minimum_considerable_usasge_in_seconds)
    )
    |> List.first()
  end

  @doc """
  Calculates usage in a given currency 
  """
  @spec calc_usage(ServerAccUser.t(), atom()) :: Money.t()
  def calc_usage(server_acc_user, currency) do
    NaiveDateTime.utc_now()
    |> NaiveDateTime.truncate(:second)
    |> NaiveDateTime.diff(server_acc_user.started_at)
    |> Decimal.new()
    |> Decimal.mult(price(server_acc_user, currency) |> Money.to_decimal())
    |> Decimal.div(@pricing_duration_in_seconds)
    |> Money.parse(currency)
    |> then(fn {:ok, money} -> money end)
  end

  @doc false
  def price(server_acc_user, currency) do
    server_acc_user.prices
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
end
