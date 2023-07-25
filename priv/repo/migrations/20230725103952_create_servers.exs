defmodule Omc.Repo.Migrations.CreateServers do
  use Ecto.Migration

  def change do
    create table(:servers) do
      add :name, :string
      add :status, :string
      add :price, :decimal
      add :max_accs, :integer
      add :description, :string
      add :user_id, references(:users, on_delete: :nothing)

      timestamps()
    end

    create unique_index(:servers, [:name])
    create index(:servers, [:user_id])
  end
end
