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
  alias Omc.Ledgers.{Ledger, LedgerTx}
  import Ecto.Query

  schema "ledger_txs" do
    field(:ledger_id, :id)
    field(:type, Ecto.Enum, values: [:credit, :debit])
    field(:amount, :integer)
    field(:context, Ecto.Enum, values: [:manual, :usage, :payment])
    field(:context_id, :id)
    timestamps(updated_at: false)
  end

  def create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [
      :ledger_id,
      :type,
      :amount,
      :context,
      :context_id
    ])
    |> validate_required([:ledger_id, :type, :amount, :context])
    |> validate_number(:amount, greater_than: 0)
    |> validate_context()
  end

  def validate_context(changeset) do
    case get_change(changeset, :context) do
      value when value in [nil, :manual] -> changeset
      _ -> validate_required(changeset, [:context_id])
    end
  end

  def ledger_tx_query(%{user_type: user_type, user_id: user_id, currency: currency}) do
    from(l in Ledger,
      join: tx in LedgerTx,
      on: l.id == tx.ledger_id,
      where: l.user_type == ^user_type and l.user_id == ^user_id and l.currency == ^currency,
      order_by: [desc: tx.id],
      select: tx
    )
  end
end
