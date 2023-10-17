defmodule Omc.Repo.Migrations.CreateUsagesTables do
  use Ecto.Migration

  def change do
    create table(:usages) do
      add :server_acc_user_id, references(:server_acc_users, on_delete: :nothing), null: false
      add :price_plan, :map, null: false
      add :started_at, :naive_datetime, null: false
      add :ended_at, :naive_datetime
    end

    create index(:usages, [:server_acc_user_id])
    create index(:usages, [:ended_at])

    create table(:usage_items) do
      add :usage_id, references(:usages, on_delete: :nothing), null: false
      add :type, :string, null: false
      add :started_at, :naive_datetime, null: false
      add :ended_at, :naive_datetime, null: false
      add :used_volume, :decimal
    end

    create index(:usage_items, [:usage_id])
    create index(:usage_items, [:type])
  end
end
