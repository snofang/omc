defmodule Omc.Ledgers.LedgerTx do
  @moduledoc """
  To hold any transaction which affect ledger's `:balance_amount`
  Actually any change in `:balance_amount` must have a record in this table and always sum of 
  records in this schema for each `:ledger_id` should yields the same `:balance_amount` as exists
  in `:ledgers` which the same `:id` referenced to via `:ledger_id`.
  """
  use Ecto.Schema
  import Ecto.Schema

  schema "ledger_txs" do
    field :ledger_id, :id

    field :credit_debit, Ecto.Enum,
      values: [:credit, :debit],
      default: :credit

    field :balance_amount, :decimal
    field :context, Ecto.Enum, values: [:manual, :ledger_acc, :payment]
    field :context_id, :id
  end
end
