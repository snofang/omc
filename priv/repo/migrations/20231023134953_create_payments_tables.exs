defmodule Omc.Repo.Migrations.CreatePaymentRequests do
  use Ecto.Migration

  def change do
    create table(:payment_requests) do
      add :user_id, :string, null: false
      add :user_type, :string, null: false
      add :money, :map, null: false
      add :ref, :string, null: false
      add :ipg, :string, null: false
      add :type, :string, null: false
      add :url, :string, null: false
      timestamps(updated_at: false)
    end

    create index(:payment_requests, [:user_id, :user_type])
    create index(:payment_requests, [:inserted_at])
    create index(:payment_requests, [:ref])

    create table(:payment_states) do
      add :payment_request_id, references(:payment_requests), null: false
      add :state, :string, null: false
      add :data, :map, null: false
      timestamps(udate_at: false)
    end

    create index(:payment_states, [:payment_request_id])
    create index(:payment_states, [:state])
  end
end
