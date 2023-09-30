defmodule Omc.Repo.Migrations.CreateServers do
  use Ecto.Migration

  def change do
    create table(:servers) do
      add(:name, :string, null: false)
      add(:status, :string, null: false)
      add(:prices, {:array, :map}, null: false)
      add(:max_accs, :integer, null: false)
      add(:description, :string)
      add(:user_id, references(:users, on_delete: :nothing), null: false)

      timestamps()
    end

    create(unique_index(:servers, [:name]))
    create(index(:servers, [:user_id]))

    create table(:server_accs) do
      add(:name, :string, null: false)
      add(:status, :string, null: false)
      add(:description, :string)
      add(:server_id, references(:servers, on_delete: :nothing), null: false)
      add(:lock_version, :integer, default: 1)
      timestamps()
    end

    create(index(:server_accs, [:server_id]))
    create(unique_index(:server_accs, [:server_id, :name]))

    create table(:server_acc_users) do
      add(:user_type, :string, null: false)
      add(:user_id, :string, null: false)
      add(:server_acc_id, references(:server_accs), null: false)
      add(:prices, :map, null: false)
      add(:started_at, :naive_datetime)
      add(:ended_at, :naive_datetime)
      timestamps()
    end

    create(index(:server_acc_users, [:user_type, :user_id]))
    create(unique_index(:server_acc_users, [:server_acc_id]))
    create index(:server_acc_users, [:inserted_at])
  end
end
