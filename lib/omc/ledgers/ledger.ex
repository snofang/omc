defmodule Omc.Ledgers.Ledger do
  use Ecto.Schema
  import Ecto.Schema
  import Ecto.Changeset

  schema "ledgers" do
    field :user_type, Ecto.Enum, values: [:local, :telegram]

    field :user_id, :string
    field :user_data, :map
    field :credit, :decimal, default: 0
    field :description, :string
    timestamps()
    has_many :ledger_txs, Omc.Ledgers.LedgerTx
    has_many :ledger_accs, Omc.Ledgers.LedgerAcc
  end

  def create_changeset(ledger, attrs, overrides \\ []) do
    ledger
    |> cast(attrs, [:user_type, :user_id, :user_data, :credit, :description])
    |> change(overrides)
    |> validate_required([:user_type, :user_id, :credit])
  end

  def update_changeset(ledger, attrs) do
    ledger
    |> cast(attrs, [:credit])
    |> validate_required([:credit])
    |> case do
      %{changes: %{credit: _}} = changeset -> changeset
      %{} = changeset -> add_error(changeset, :credit, "did not change")
    end
  end
end
