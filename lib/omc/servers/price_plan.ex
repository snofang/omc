defmodule Omc.Servers.PricePlan do
  use Ecto.Schema

  import Ecto.Schema
  import Ecto.Changeset

  schema "price_plans" do
    field(:name, :string)
    field(:duration, :integer)
    field(:prices, {:array, Money.Ecto.Map.Type})
    field(:max_volume, :integer)
    field(:extra_volume_prices, {:array, Money.Ecto.Map.Type})
    timestamps(updated_at: false)
  end

  def create_changeset(attrs \\ %{}) do
    %__MODULE__{}
    |> cast(attrs, [:name, :duration, :prices, :max_volume, :extra_volume_prices])
    |> validate_required([:name, :duration, :prices])
    |> validate_prices_not_empty_or_nil()
    |> validate_prices_to_have_all_supported_currencies()
  end

  defp validate_prices_not_empty_or_nil(changeset) do
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

  defp validate_prices_to_have_all_supported_currencies(changeset) do
    changeset
    |> validate_change(:prices, fn :prices, prices ->
      prices
      |> Enum.reduce([], fn %{currency: currency}, currencies -> [currency | currencies] end)
      |> Enum.uniq()
      |> Enum.sort()
      |> Kernel.==(Application.get_env(:omc, :supported_currencies) |> Enum.sort())
      |> case do
        true ->
          []

        false ->
          [prices: "price plan should have all supported currencies"]
      end
    end)
  end

  @spec price(%__MODULE__{}, atom()) :: Money.t()
  def price(%__MODULE__{} = price_plan, currency) do
    price_plan.prices
    |> Enum.find(fn price -> price.currency == currency end)
  end

  def to_string_duration_days_no_name(%__MODULE__{} = pp) do
    "#{(pp.duration / (24 * 60 * 60)) |> trunc} days - #{pp.prices |> Enum.map(&Money.to_string/1) |> Enum.join(", ")}"
  end
end
