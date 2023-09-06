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
    field :delete, :boolean, virtual: true
    has_many :server_accs, Omc.Servers.ServerAcc, foreign_key: :server_id, references: :id

    timestamps()
  end

  def changeset(server, %{delete: true}) do
    change(server, %{delete: true})
    |> no_assoc_constraint(:server_accs,
      message: "server having accs can not be deleted"
    )
  end

  @doc false
  def changeset(server, attrs) do
    server
    |> cast(attrs, [:name, :status, :price, :max_accs, :description, :user_id])
    |> validate_required([:name, :status, :user_id, :price, :max_accs])
    |> unique_constraint(:name)
    |> validate_format(:name, name_format())
  end

  def name_format() do
    ~r/^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])$/
  end
end
