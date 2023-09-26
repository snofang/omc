defmodule Omc.Ledgers.Ledger do
  use Ecto.Schema
  import Ecto.Schema
  import Ecto.Changeset

  schema "ledgers" do
    field :user_type, Ecto.Enum, values: [:local, :telegram]
    field :user_id, :string
    field :user_data, :map, default: %{}
    field :currency, :string
    field :credit, :integer, default: 0
    field :description, :string
    field :lock_version, :integer, default: 1
    timestamps()
    # has_many :ledger_txs, Omc.Ledgers.LedgerTx
    # has_many :ledger_accs, Omc.Ledgers.LedgerAcc
  end

  def create_changeset(ledger, attrs) do
    ledger
    |> cast(attrs, [:user_type, :user_id, :user_data, :currency, :credit, :description])
    |> validate_required([:user_type, :user_id, :currency, :credit])
  end

  def update_changeset(ledger, attrs) do
    ledger
    |> cast(attrs, [:credit])
    |> validate_required([:credit])
    |> optimistic_lock(:lock_version)
    |> case do
      %{changes: %{credit: _}} = changeset -> changeset
      %{} = changeset -> add_error(changeset, :credit, "did not change")
    end
  end
end
