defmodule Omc.Repo.Migrations.CreateServers do
  use Ecto.Migration

  def change do
    create table(:servers) do
      add :name, :string, null: false
      add :status, :string, null: false
      add :price, :decimal, null: false
      add :max_accs, :integer, null: false
      add :description, :string
      add :user_id, references(:users, on_delete: :nothing), null: false

      timestamps()
    end

    create unique_index(:servers, [:name])
    create index(:servers, [:user_id])
  end
end
