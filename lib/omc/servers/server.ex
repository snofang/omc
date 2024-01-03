defmodule Omc.Servers.Server do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Schema
  alias Omc.Servers.ServerOps
  alias Omc.Servers.PricePlan

  schema "servers" do
    field(:address, :string)
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
    |> cast(attrs, [:address, :name, :status, :price_plan_id, :tag, :max_acc_count])
    |> change(params)
    |> validate_required([:address, :name, :status, :price_plan_id, :tag, :max_acc_count])
    |> validate_format(:tag, ~r/^[a-zA-Z0-9]+\-[a-zA-Z0-9]+$/)
    |> unique_constraint(:name)
    |> unique_constraint(:address)
    |> validate_format(:name, ip_domain_format())
    |> validate_format(:address, ip_domain_format())
    |> no_assoc_constraint(:server_accs, message: "A server having acc(s) can not be deleted")
    |> validate_number(:max_acc_count, greater_than: 0)
    |> validate_name_change()
  end

  def ip_domain_format() do
    # domain or IP
    ~r/^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$|^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)+([A-Za-z]|[A-Za-z][A-Za-z0-9\-]*[A-Za-z0-9])$/
  end

  def validate_name_change(changeset) do
    changeset
    |> validate_change(:name, fn :name, _name ->
      if ServerOps.conf_exist?(changeset.data.id) do
        [{:name, "after server config, name should not be changed."}]
      else
        []
      end
    end)
  end
end
