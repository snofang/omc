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

  @pricing_duration_in_seconds 30 * 24 * 60 * 60

  defmodule UsageState do
    @moduledoc false
    defstruct ledgers: [],
              server_acc_users: [],
              ledger_changesets: [],
              ledger_tx_changesets: [],
              server_acc_user_changeset: []

    def add_usage_tx(%__MODULE__{} = state, %Ledger{} = ledger, %Money{} = money) do
      Ledgers.ledger_update_changeset(%{
        ledger: ledger,
        context: :usage,
        amount: money.amount,
        type: :debit
      })
      |> then(fn %{ledger_changeset: ledger_changeset, ledger_tx_changeset: ledger_tx_changeset} ->
        state
        |> add_ledger_changeset(ledger_changeset)
        |> apply_ledger_changeset(ledger_changeset)
        |> add_ledger_tx_changeset(ledger_tx_changeset)
      end)
    end

    defp add_ledger_tx_changeset(%__MODULE__{} = state, changeset) do
      state
      |> Map.replace(:ledger_tx_changesets, state.ledger_tx_changesets ++ [changeset])
    end

    defp add_ledger_changeset(%__MODULE__{} = state, changeset) do
      state
      |> Map.replace(:ledger_changesets, state.ledger_changesets ++ [changeset])
    end

    defp apply_ledger_changeset(%__MODULE__{} = state, changeset) do
      state
      |> Map.replace(
        :ledgers,
        state.ledgers
        |> Enum.map(fn ledger ->
          if ledger.id == changeset.data.id do
            Ecto.Changeset.apply_changes(changeset)
          else
            ledger
          end
        end)
      )
    end
  end

  @doc """
  Gives current usage state (without persisting anything) in terms of current computed last state of 
    `Ledger`s and companied by `LedgerTx`s, `ServerAccUser`s, and their corresponding changesets.
  """
  def usage_state(%{user_type: _user_type, user_id: _user_id} = attrs) do
    %UsageState{
      ledgers: Ledgers.get_ledgers(attrs),
      server_acc_users: ServerAccUsers.get_server_acc_users_in_use(attrs)
    }
    |> usage_state()
    |> then(
      &%{
        ledger_tx_changesets: &1.ledger_tx_changesets,
        server_acc_user_changesets: &1.server_acc_user_changesets
      }
    )
  end

  @doc false
  def usage_state(%UsageState{} = state) do
    case first_in_use_server_acc_user(state.server_acc_users) do
      nil ->
        state

      sau ->
        case first_oldest_no_zero_credit_ledger(state.ledgers) do
          # No credit, going to make last used ledger's credit negetive
          nil ->
            first_newset_used_credit(state.ledgers)
            |> use_credit(sau, state)
            |> usage_state()

          # Some credit, going to use it.
          ledger ->
            ledger
            |> use_credit(sau, state)
            |> usage_state()
        end
    end
  end

  @doc false
  def use_credit(%Ledger{} = ledger, %ServerAccUser{} = sau, %UsageState{} = state) do
    (amount = usage_amount(sau, ledger.currency))
    |> Money.compare(Money.new(ledger.credit, ledger.currency))
    |> case do
      # usage amount is less than credit
      1 ->
        # TODO
        raise "not supported yet"

      # usage amount is less than or equal credit
      _ ->
        state
        |> UsageState.add_usage_tx(ledger, amount)
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
  def first_in_use_server_acc_user([%ServerAccUser{}] = server_acc_users) do
    server_acc_users
    |> Enum.filter(&(&1.started_at != nil and &1.ended_at == nil))
    |> List.first()
  end

  # Calculates usage in a given currency; rerurning result in decimal
  # TODO: for each supported payment, there should be a price.
  @doc false
  @spec usage_amount(ServerAccUser.t(), atom()) :: Money.t()
  def usage_amount(server_acc_user, currency) do
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
end
