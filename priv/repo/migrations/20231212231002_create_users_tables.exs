defmodule Omc.Repo.Migrations.CreateUserInfo do
  use Ecto.Migration

  def change do
    create table(:user_info) do
      add :user_type, :string, null: false
      add :user_id, :string, null: false
      add :user_name, :string
      add :first_name, :string
      add :last_name, :string
      add :language_code, :string

      timestamps()
    end

    create unique_index(:user_info, [:user_id, :user_type])
    create index(:user_info, [:user_name])
    create index(:user_info, [:first_name])
    create index(:user_info, [:last_name])
  end
end
