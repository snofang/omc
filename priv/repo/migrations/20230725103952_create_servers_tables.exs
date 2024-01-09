defmodule Omc.Repo.Migrations.CreateServersTables do
  use Ecto.Migration

  def change do
    create table(:price_plans) do
      add :name, :string, null: false
      add :duration, :integer, null: false
      add :prices, :map, null: false
      add :max_volume, :integer, null: true
      add :extra_volume_prices, :map, null: true
      timestamps(updated_at: false)
    end

    create table(:servers) do
      add :address, :string, null: false
      add :name, :string, null: false
      add :status, :string, null: false
      add :price_plan_id, references(:price_plans, on_delete: :nothing), null: false
      add :tag, :string, null: false
      add :max_acc_count, :integer, null: false
      timestamps()
    end

    create unique_index(:servers, [:name])
    create unique_index(:servers, [:address])
    create index(:servers, [:price_plan_id])
    create index(:servers, [:tag])

    create table(:server_accs) do
      add :status, :string, null: false
      add :server_id, references(:servers, on_delete: :nothing), null: false
      add :lock_version, :integer, default: 1
      timestamps()
    end

    create index(:server_accs, [:server_id])

    create table(:server_acc_users) do
      add :user_type, :string, null: false
      add :user_id, :string, null: false
      add :server_acc_id, references(:server_accs), null: false
      add :allocated_at, :naive_datetime, null: false
      add :started_at, :naive_datetime
      add :ended_at, :naive_datetime
      add :lock_version, :integer, default: 1
      timestamps()
    end

    create index(:server_acc_users, [:user_id, :user_type])
    create unique_index(:server_acc_users, [:server_acc_id])
    create index(:server_acc_users, [:started_at, :ended_at])
  end
end
