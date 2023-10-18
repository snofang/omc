defmodule Omc.Usages.Usage do
  use Ecto.Schema
  alias Omc.Common.PricePlan
  alias Omc.Usages.UsageItem
  import Ecto.Schema
  import Ecto.Changeset

  schema "usages" do
    field :server_acc_user_id, :id
    embeds_one :price_plan, PricePlan
    field :started_at, :naive_datetime
    field :ended_at, :naive_datetime
    has_many :usage_items, UsageItem
  end

  @doc false
  def create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:server_acc_user_id])
    |> put_embed(:price_plan, attrs.price_plan)
    |> change(started_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second))
    |> validate_required([:server_acc_user_id, :price_plan, :started_at])
  end

  def update_changeset(%__MODULE__{} = usage) do
    usage
    |> change(ended_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second))
  end
end
