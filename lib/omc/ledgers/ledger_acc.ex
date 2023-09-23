defmodule Omc.Ledgers.LedgerAcc do
  use Ecto.Schema
  import Ecto.Schema

  schema "ledger_accs" do
    field :ledger_id, :id
    field :server_acc_id, :id
    field :price_per_day, :integer
    field :activated_at, :naive_datetime
    field :deactivated_at, :naive_datetime
  end
end
