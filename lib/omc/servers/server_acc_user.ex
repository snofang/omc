defmodule Omc.Servers.ServerAccUser do
  use Ecto.Schema
  import Ecto.Schema
  import Ecto.Changeset

  schema "server_acc_users" do
    field :user_type, Ecto.Enum, values: [:local, :telegram]
    field :user_id, :string
    field :server_acc_id, :id
    field :prices, {:array, Money.Ecto.Map.Type}
    field :started_at, :naive_datetime
    field :ended_at, :naive_datetime
    timestamps()
  end

  def create_chageset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [
      :user_type,
      :user_id,
      :server_acc_id,
      :prices
    ])
    |> unique_constraint([:server_acc_id])
  end
end
