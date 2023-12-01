defmodule Omc.Usages.Usage do
  use Ecto.Schema
  alias Omc.Servers.PricePlan
  alias Omc.Usages.UsageItem
  import Ecto.Schema
  import Ecto.Changeset

  schema "usages" do
    field(:server_acc_user_id, :id)
    belongs_to(:price_plan, PricePlan)
    field(:started_at, :naive_datetime)
    field(:ended_at, :naive_datetime)
    has_many(:usage_items, UsageItem)
  end

  @doc false
  def create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:server_acc_user_id, :price_plan_id])
    |> change(started_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second))
    |> validate_required([:server_acc_user_id, :price_plan_id, :started_at])
  end

  def end_changeset(%__MODULE__{} = usage) do
    usage
    |> change(ended_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second))
  end
end
