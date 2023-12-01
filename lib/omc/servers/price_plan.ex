defmodule Omc.Servers.PricePlan do
  use Ecto.Schema

  import Ecto.Schema
  import Ecto.Changeset

  schema "price_plans" do
    field :name, :string
    field :duration, :integer
    field :prices, {:array, Money.Ecto.Map.Type}
    field :max_volume, :integer
    field :extra_volume_prices, {:array, Money.Ecto.Map.Type}
    timestamps(updated_at: false)
  end

  def create_changeset(attrs \\ %{}) do
    %__MODULE__{}
    |> cast(attrs, [:name, :duration, :prices, :max_volume, :extra_volume_prices])
    |> validate_required([:name, :duration, :prices])
    |> validate_prices()
  end

  defp validate_prices(changeset) do
    changeset
    |> validate_change(:prices, fn :prices, prices ->
      case prices do
        [] ->
          [prices: "prices can not be empty"]

        prices ->
          prices
          |> Enum.reduce([], fn money, errors ->
            if money do
              errors
            else
              [{:prices, "price can not be nil"} | errors]
            end
          end)
      end
    end)
  end

  @spec price(%__MODULE__{}, atom()) :: Money.t()
  def price(%__MODULE__{} = price_plan, currency) do
    price_plan.prices
    |> Enum.find(fn price -> price.currency == currency end)
  end
end
