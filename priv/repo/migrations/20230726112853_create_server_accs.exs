defmodule Omc.Repo.Migrations.CreateServerAccs do
  use Ecto.Migration

  def change do
    create table(:server_accs) do
      add :name, :string
      add :status, :string
      add :description, :string
      add :server_id, references(:servers, on_delete: :nothing)

      timestamps()
    end

    create index(:server_accs, [:server_id])
  end
end
