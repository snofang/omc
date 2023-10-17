defmodule Omc.Usages.UsageItem do
  use Ecto.Schema
  import Ecto.Schema
  import Ecto.Changeset

  schema "usage_items" do
    field :usage_id, :id
    field :type, Ecto.Enum, values: [:duration, :volume]
    field :started_at, :naive_datetime
    field :ended_at, :naive_datetime
    field :used_volume, :decimal
  end

  def create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:usage_id, :type, :started_at, :ended_at])
    |> validate_required([:usage_id, :type, :started_at, :ended_at])
  end
end
