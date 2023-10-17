defmodule Omc.Servers.Server do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Schema
  alias Omc.Common.PricePlan

  schema "servers" do
    field :description, :string
    field :max_accs, :integer
    field :name, :string
    # TODO: To remove this after adding multiple price support 
    field :price, :string, virtual: true
    embeds_many :price_plans, PricePlan, on_replace: :delete
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
    # |> cast_embed(:price_plans, required: true)
    |> validate_format(:price, ~r/^\d*(\.\d{1,2})?$/)
    |> put_price_change()
    |> unique_constraint(:name)
    |> validate_format(:name, name_format())
    |> no_assoc_constraint(:server_accs, message: "A server having acc(s) can not be deleted")
  end

  def name_format() do
    ~r/^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])$/
  end

  # TODO: to remove this after adding muti-currency support
  def put_price_change(changeset) do
    if value = changeset |> get_change(:price) do
      case value
           |> Money.parse() do
        {:ok, money} ->
          changeset
          |> put_embed(:price_plans, [
            %PricePlan{
              name: "default",
              duration_days: 30,
              prices: [money]
            }
          ])

        _ ->
          changeset
          |> add_error(
            :price,
            "Invalid price format"
          )
      end
    else
      changeset
    end
  end

  # TODO: to remove this after adding muti-currency support
  def put_price(nil), do: nil

  def put_price(server) do
    Map.put(
      server,
      :price,
      server.price_plans
      |> List.first()
      |> then(fn price_plan -> price_plan.prices end)
      |> List.first()
      |> then(fn money -> Decimal.new(money.amount) |> Decimal.div(100) |> to_string() end)
    )
  end
end
