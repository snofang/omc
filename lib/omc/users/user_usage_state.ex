defmodule Omc.Users.UserUsageState do
  alias Omc.Ledgers
  alias Omc.Ledgers.Ledger

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
