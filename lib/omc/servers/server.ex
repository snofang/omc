defmodule Omc.Servers.Server do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Schema

  schema "servers" do
    field :description, :string
    field :max_accs, :integer
    field :name, :string
    field :price, :decimal
    field :status, Ecto.Enum, values: [:active, :deactive]
    field :user_id, :id
    has_many :server_accs, Omc.Servers.ServerAcc

    timestamps()
  end

  @doc false
  def changeset(server, attrs) do
    server
    |> cast(attrs, [:name, :status, :price, :max_accs, :description, :user_id])
    |> validate_required([:name, :status, :user_id, :price, :max_accs])
    |> unique_constraint(:name)
    |> validate_format(:name, name_format())
    |> no_assoc_constraint(:server_accs, message: "A server having acc(s) can not be deleted")
  end

  def name_format() do
    ~r/^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])$/
  end
end
