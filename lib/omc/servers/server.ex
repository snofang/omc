defmodule Omc.Servers.Server do
  use Ecto.Schema
  import Ecto.Changeset

  schema "servers" do
    field :description, :string
    field :max_accs, :integer
    field :name, :string
    field :price, :decimal
    field :status, Ecto.Enum, values: [:active, :deactive]
    field :user_id, :id

    timestamps()
  end

  @doc false
  def changeset(server, attrs) do
    server
    |> cast(attrs, [:name, :status, :price, :max_accs, :description, :user_id])
    |> validate_required([:name, :status, :user_id, :price, :max_accs])
    |> unique_constraint(:name)
  end
end
