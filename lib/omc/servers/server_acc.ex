defmodule Omc.Servers.ServerAcc do
  use Ecto.Schema
  import Ecto.Changeset

  schema "server_accs" do
    import Ecto.Schema
    field :description, :string
    field :name, :string

    field :status, Ecto.Enum,
      values: [:active_pending, :active, :deactive_pending, :deactive],
      default: :active_pending

    field :server_id, :id
    field :lock_version, :integer, default: 1
    field :delete, :boolean, virtual: true, default: false

    timestamps()
  end

  @doc false
  def changeset(server_acc, %{delete: true}) do
    server_acc
    |> change(%{status: :dummy_status})
    |> validate_delete()
  end

  @doc false
  def changeset(server_acc, attrs) do
    server_acc
    |> cast(attrs, [:name, :status, :description, :server_id])
    |> validate_required([:name, :status, :server_id])
    |> validate_format(:name, ~r/^[\w]+[\w\-]*[\w]+$/)
    |> validate_status()
    |> validate_update_name()
    |> optimistic_lock(:lock_version)
    |> unique_constraint([:server_id, :name], error_key: :name)
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

  defp validate_update_name(changeset) do
    changeset
    |> validate_change(:name, fn :name, _new_name ->
      case changeset.data.status do
        :active_pending ->
          if(new_status = changeset.changes |> Map.get(:status)) do
            [
              {:name,
               {"name field can not be changed while status is changing to %{new_status}",
                [new_status: new_status]}}
            ]
          else
            []
          end

        _ ->
          [{:name, {"name can not be changed while status is not :active_pending", []}}]
      end
    end)
  end
end
