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
    field(:max_acc_count, :integer)
    has_many(:server_accs, Omc.Servers.ServerAcc)
    timestamps()
  end

  @doc false
  def changeset(server, attrs, params \\ %{}) do
    server
    |> cast(attrs, [:name, :status, :price_plan_id, :tag, :max_acc_count])
    |> change(params)
    |> validate_required([:name, :status, :price_plan_id, :tag, :max_acc_count])
    |> validate_format(:tag, ~r/^[a-zA-Z0-9]+\-[a-zA-Z0-9]+$/)
    |> unique_constraint(:name)
    |> validate_format(:name, name_format())
    |> no_assoc_constraint(:server_accs, message: "A server having acc(s) can not be deleted")
    |> validate_number(:max_acc_count, greater_than: 0)
  end

  def name_format() do
    ~r/^(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)*[a-z0-9][a-z0-9-]{0,61}[a-z0-9]$/
  end
end
