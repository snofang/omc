defmodule Omc.Payments.PaymentRequest do
  use Ecto.Schema
  import Ecto.Schema
  import Ecto.Changeset
  alias Omc.Payments.PaymentState

  schema "payment_requests" do
    field(:user_id, :string)
    field(:user_type, Ecto.Enum, values: [:telegram, :local])
    field(:money, Money.Ecto.Map.Type)
    field(:ref, :string)
    field(:ipg, Ecto.Enum, values: [:oxapay, :nowpayments])
    field(:type, Ecto.Enum, values: [:push, :pull])
    field(:url, :string)
    field :data, :map
    field :user_info, :string, virtual: true
    field :paid_sum, :integer, virtual: true
    has_many(:payment_states, PaymentState)
    timestamps(updated_at: false)
  end

  @doc false
  def create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:user_id, :user_type, :money, :ref, :ipg, :type, :url, :data])
  end
end
