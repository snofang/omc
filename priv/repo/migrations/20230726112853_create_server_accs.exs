defmodule Omc.Repo.Migrations.CreateServerAccs do
  use Ecto.Migration

  def change do
    create table(:server_accs) do
      add :name, :string, null: false
      add :status, :string, null: false
      add :description, :string
      add :server_id, references(:servers, on_delete: :nothing), null: false
      add :lock_version, :integer, default: 1

      timestamps()
    end

    create index(:server_accs, [:server_id])
    create unique_index(:server_accs, [:server_id, :name])
  end
end
