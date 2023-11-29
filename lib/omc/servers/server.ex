defmodule Omc.Servers.Server do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Schema
  alias Omc.Common.PricePlan

  schema "servers" do
    field(:tag, :string)
    field(:name, :string)
    # TODO: To remove this after adding multiple price support 
    field(:price, :string, virtual: true)
    embeds_many(:price_plans, PricePlan, on_replace: :delete)
    field(:status, Ecto.Enum, values: [:active, :deactive])
    has_many(:server_accs, Omc.Servers.ServerAcc)

    timestamps()
  end

  @doc false
  def changeset(server, attrs, params \\ %{}) do
    server
    |> cast(attrs, [:name, :status, :price, :tag])
    |> change(params)
    |> validate_required([:name, :status, :price, :tag])
    # |> cast_embed(:price_plans, required: true)
    |> validate_format(:price, ~r/^\d*(\.\d{1,2})?$/)
    |> validate_format(:tag, ~r/^[a-zA-Z0-9]+\-[a-zA-Z0-9]+$/)
    |> put_price_change()
    |> unique_constraint(:name)
    |> validate_format(:name, name_format())
    |> no_assoc_constraint(:server_accs, message: "A server having acc(s) can not be deleted")
  end

  def name_format() do
    ~r/^([a-zA-Z0-9]([a-zA-Z0-9\-]*[a-zA-Z0-9])*\.)*[A-Za-z0-9]([A-Za-z0-9\-]*[A-Za-z0-9])*$/
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
              id: 1,
              name: "default",
              duration: 30 * 24 * 60 * 60,
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
      default_price(server)
      |> then(fn money -> money |> Money.to_decimal() |> Decimal.to_string() end)
    )
  end

  @spec default_price(%__MODULE__{}) :: Money.t()
  def default_price(server) do
    server.price_plans
    |> List.first()
    |> then(fn price_plan -> price_plan.prices end)
    |> List.first()
  end
end
