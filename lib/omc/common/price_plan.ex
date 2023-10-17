defmodule Omc.Common.PricePlan do
  use Ecto.Schema
  import Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    field :name, :string
    field :duration_days, :integer
    field :prices, {:array, Money.Ecto.Map.Type}
    field :max_volume, :integer
    field :extra_volume_prices, {:array, Money.Ecto.Map.Type}
  end

  def changeset(%__MODULE__{} = price_plan, attrs \\%{}) do
    price_plan
    |> cast(attrs, [:name, :duration_days, :prices, :max_volume_gb, :extra_volume_gb_prices])
    |> validate_required([:name, :duration_days, :prices])
  end
end
