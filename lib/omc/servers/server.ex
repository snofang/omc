defmodule Omc.Servers.Server do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Schema
  alias Omc.Servers.PricePlan

  schema "servers" do
    field(:name, :string)
    field(:status, Ecto.Enum, values: [:active, :deactive])
    belongs_to(:price_plan, PricePlan)
    field(:tag, :string)
    has_many(:server_accs, Omc.Servers.ServerAcc)
    timestamps()
  end

  @doc false
  def changeset(server, attrs, params \\ %{}) do
    server
    |> cast(attrs, [:name, :status, :price_plan_id, :tag])
    |> change(params)
    |> validate_required([:name, :status, :price_plan_id, :tag])
    |> validate_format(:tag, ~r/^[a-zA-Z0-9]+\-[a-zA-Z0-9]+$/)
    |> unique_constraint(:name)
    |> validate_format(:name, name_format())
    |> no_assoc_constraint(:server_accs, message: "A server having acc(s) can not be deleted")
  end

  def name_format() do
    ~r/^([a-zA-Z0-9]([a-zA-Z0-9\-]*[a-zA-Z0-9])*\.)*[A-Za-z0-9]([A-Za-z0-9\-]*[A-Za-z0-9])*$/
  end
end
