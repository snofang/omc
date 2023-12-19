defmodule Omc.Repo.Migrations.CreateLedgersTables do
  use Ecto.Migration

  def change do
    create table(:ledgers) do
      # This can be :local, :telegram, or any other places where users authenticated and identified uniquely
      add :user_type, :string, null: false
      # This references nowhere for flexibility
      add :user_id, :string, null: false
      add :currency, :string, null: false
      add :user_data, :map, default: %{}, null: false
      add :credit, :bigint, default: 0, null: false
      add :description, :string
      add :lock_version, :integer, default: 1
      timestamps()
    end

    create unique_index(:ledgers, [:user_type, :user_id, :currency])

    create table(:ledger_txs) do
      add :ledger_id, references(:ledgers), null: false
      # Posible values: :credit, :debit
      add :type, :string, null: false
      add :amount, :bigint, null: false
      # To specify the source or cause of this; e.g. :manual, :usage, :payment, etc.
      add :context, :string, null: false
      # Nornally this should refer to a table(e.g. :payments, :ledger_accs, etc.),
      # and in case of manual it can be null
      add :context_id, :id, null: true
      add :context_ref, :string, null: true
      timestamps(updated_at: false)
    end

    create index(:ledger_txs, [:ledger_id])
    create index(:ledger_txs, [:context, :context_id])
  end
end
