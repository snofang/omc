defmodule Omc.PricePlans do
  alias Omc.Servers.PricePlan
  alias Omc.Repo
  import Ecto.Query

  @doc """
  Create a new `PricePlan`.
  ## Options:
    * `:name` - specifies plan's name. default value is `default`.
    * `:duration` - duration subject of price in seconds. default is 30 days.
  """
  @spec create_price_plan(prices :: [Money.t()], Keyword.t()) ::
          {:ok, %PricePlan{}} | {:error, term()}
  def create_price_plan(prices, opts \\ []) do
    opts = Keyword.validate!(opts, name: "default", duration: 30 * 24 * 60 * 60)

    PricePlan.create_changeset(%{
      name: opts[:name],
      prices: prices,
      duration: opts[:duration]
    })
    |> Repo.insert()
  end

  def list_price_plans(opts \\ []) do
    PricePlan
    |> price_plans_by_name(opts)
    |> Repo.all()
  end

  defp price_plans_by_name(price_plans, opts) do
    if(opts[:name]) do
      price_plans
      |> where(name: ^opts[:name])
    else
      price_plans
    end
  end

  def get_price_plan!(id) do
    PricePlan
    |> Repo.get!(id)
  end
end
