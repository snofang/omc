defmodule Omc.Servers.ServerAccUser do
  use Ecto.Schema
  import Ecto.Schema
  import Ecto.Changeset

  schema "server_acc_users" do
    field(:user_type, Ecto.Enum, values: [:local, :telegram])
    field(:user_id, :string)
    field(:server_acc_id, :id)
    field(:prices, {:array, Money.Ecto.Map.Type})
    field(:allocated_at, :naive_datetime)
    field(:started_at, :naive_datetime)
    field(:ended_at, :naive_datetime)
    field(:lock_version, :integer, default: 1)
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
    |> allocate_changeset()
    |> unique_constraint([:server_acc_id])
  end

  def allocate_changeset(data) do
    data
    |> change(%{allocated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)})
    |> optimistic_lock(:lock_version)
  end

  @doc """
  Starts acc usage by setting `started_at`.
  """
  def start_changeset(data) do
    data
    |> change(%{started_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)})
    |> optimistic_lock(:lock_version)
  end

  @doc """
  Ends acc usage by setting `ended_at`.
  """
  def end_changeset(data) do
    data
    |> change(%{ended_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)})
    |> optimistic_lock(:lock_version)
    |> case do
      changeset when changeset.data.started_at == nil ->
        changeset
        |> add_error(:started_at, "It's not possible to end a server_acc_user, when not started")

      changeset ->
        changeset
    end
  end
end
