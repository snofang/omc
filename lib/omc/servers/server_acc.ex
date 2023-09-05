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

    timestamps()
  end

  @doc false
  def changeset(server_acc, attrs) do
    server_acc
    |> cast(attrs, [:name, :status, :description, :server_id])
    |> validate_required([:name, :status, :server_id])
    |> validate_format(:name, ~r/^[\w]+[\w\-]*[\w]+$/)
    |> validate_status()
    |> optimistic_lock(:lock_version)
  end

  def validate_status(changeset) do
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
end
