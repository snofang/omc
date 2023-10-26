defmodule Omc.Payments.PaymentState do
  use Ecto.Schema
  import Ecto.Schema
  import Ecto.Changeset

  schema "payment_states" do
    field(:payment_request_id, :id)
    field(:state, Ecto.Enum, values: [:pending, :completed, :cancelled])
    field :data, :map
    timestamps(updated_at: false)
  end

  def create_changeset(%{} = attrs) do
    %__MODULE__{}
    |> cast(attrs, [:payment_request_id, :state, :data])
  end
end
