defmodule Omc.Servers.ServerAcc do
  use Ecto.Schema
  import Ecto.Changeset

  schema "server_accs" do
    import Ecto.Schema
    field :description, :string
    field :name, :string
    field :status, Ecto.Enum, values: [:active, :deactive]
    field :server_id, :id

    timestamps()
  end

  @doc false
  def changeset(server_acc, attrs) do
    server_acc
    |> cast(attrs, [:name, :status, :description, :server_id])
    |> validate_required([:name, :status, :server_id])
  end
end
