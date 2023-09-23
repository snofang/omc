defmodule Omc.Ledgers.LedgerTx do
  @moduledoc """
  To hold any transaction which affect ledger's `:credit`
  Any changes in ledger's `:credit` must have a record in this schema and always sum of 
  records in this schema for each `:ledger_id` should yields the same `:credit` amount as exists
  in `:ledgers` which the same `:id` referenced to via `:ledger_id`.
  """
  use Ecto.Schema
  import Ecto.Schema
  import Ecto.Changeset

  schema "ledger_txs" do
    field :ledger_id, :id
    field :type, Ecto.Enum, values: [:credit, :debit]
    field :currency, :string
    field :amount, :integer
    field :context, Ecto.Enum, values: [:manual, :ledger_acc, :payment]
    field :context_id, :id
    timestamps(updated_at: false)
  end

  def create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [
      :ledger_id,
      :type,
      :currency,
      :amount,
      :context,
      :context_id
    ])
    |> validate_required([:ledger_id, :type, :currency, :amount, :context])
    |> validate_number(:amount, greater_than: 0)
    |> validate_context()
  end

  def validate_context(changeset) do
    case get_change(changeset, :context) do
      value when value in [nil, :manual] -> changeset
      _ -> validate_required(changeset, [:context_id])
    end
  end
end
