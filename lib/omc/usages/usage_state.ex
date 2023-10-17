defmodule Omc.Usages.UsageState do
  @moduledoc """
  Holds and expresses the last usage(credits & expenses) state of a `user` 
  for the running(`allocated` and `started`) accounts (`ServerAcc`).
  This includes those records that have already persisted and the new ones. For
  the new ones the corresponding changesets also collected to aid in persisting 
  this state if needed or wanted.
  """
  alias Omc.Ledgers
  alias Omc.Usages.UsageItem

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
