defmodule Omc.Servers.ServerAcc do
  use Ecto.Schema
  import Ecto.Changeset

  schema "server_accs" do
    field(:status, Ecto.Enum,
      values: [:active_pending, :active, :deactive_pending, :deactive],
      default: :active_pending
    )

    field(:server_id, :id)
    field(:lock_version, :integer, default: 1)
    field(:delete, :boolean, virtual: true, default: false)
    field(:user_info, :string, virtual: true)
    timestamps()
  end

  @doc false
  def changeset(server_acc, %{delete: true}) do
    server_acc
    |> change(%{status: :dummy_status})
    |> validate_delete()
  end

  @doc false
  def changeset(server_acc, attrs, params \\ %{}) do
    server_acc
    |> cast(attrs, [:status, :server_id])
    |> change(params)
    |> validate_required([:status, :server_id])
    |> validate_status()
    |> optimistic_lock(:lock_version)
  end

  defp validate_status(changeset) do
    validate_change(changeset, :status, fn :status, new_status ->
      case {changeset.data.status, new_status} do
        {nil, :active_pending} ->
          []

        {:active_pending, :active} ->
          []

        {:active, :deactive_pending} ->
          []

        {:deactive_pending, :deactive} ->
          []

        {old, new} ->
          [
            status:
              {"It's not possible to change status from %{old} to %{new}", [old: old, new: new]}
          ]
      end
    end)
  end

  defp validate_delete(changeset) do
    changeset
    |> validate_change(:status, fn :status, _new_status ->
      if changeset.data.status == :active_pending do
        []
      else
        [{:status, "only acc's with initial status active_pending can be deleted"}]
      end
    end)
  end

  def name(%__MODULE__{} = sa) do
    name(sa.id)
  end

  def name(id) when is_integer(id) do
    id |> to_string() |> String.pad_leading(5, "0")
  end
end
