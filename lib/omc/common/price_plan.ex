defmodule Omc.Common.PricePlan do
  use Ecto.Schema
  import Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    field :name, :string
    field :duration, :integer
    field :prices, {:array, Money.Ecto.Map.Type}
    field :max_volume, :integer
    field :extra_volume_prices, {:array, Money.Ecto.Map.Type}
  end

  def changeset(%__MODULE__{} = price_plan, attrs \\ %{}) do
    price_plan
    |> cast(attrs, [:name, :duration, :prices, :max_volume, :extra_volume_prices])
    |> validate_required([:name, :duration, :prices])
  end

  @spec price(%__MODULE__{}, atom()) :: Money.t()
  def price(%__MODULE__{} = price_plan, currency) do
    price_plan.prices
    |> Enum.find(fn price -> price.currency == currency end)
  end
end
