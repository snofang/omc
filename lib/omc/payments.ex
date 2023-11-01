defmodule Omc.Payments do
  require Logger
  alias Omc.Payments.{PaymentRequest, PaymentState}
  alias Omc.Payments.PaymentProvider
  import Ecto.Query
  alias Omc.Repo

  def create_payment_request(ipg, %{user_id: user_id, user_type: user_type, money: money}) do
    %{
      user_id: user_id,
      user_type: user_type,
      money: money,
      ipg: ipg
    }
    |> PaymentProvider.send_paymet_request()
    |> case do
      {:ok, params} ->
        PaymentRequest.create_changeset(params)
        |> Repo.insert()

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Handles callback from an `ipg` and creates new status update record related 
  to already existing `Omc.Payments.PaymentRequest`

  The callback is normally a web api call, it receives both `params` and `body` of given call 
  and passes them to underliying provider for detail processing and calculating resulted 
  new status.
    
  returns response used to be returned as the web api requestd callback.
  """
  @spec callback(atom(), map(), map() | nil) :: {:ok, term()} | {:error, term()}
  def callback(ipg, params, body) do
    case PaymentProvider.callback(ipg, params, body) do
      {:ok, state_attrs = %{ref: ref, state: _state, data: _date}, res} ->
        get_payment_request(ref)
        |> case do
          nil ->
            {:error, :not_found}

          request ->
            {:ok, _state} = insert_payment_state(request, state_attrs)
            {:ok, res}
        end

      {:error, res} ->
        {:error, res}
    end
  end

  defp insert_payment_state(payment_request, attrs) do
    attrs
    |> Map.put(:payment_request_id, payment_request.id)
    |> PaymentState.create_changeset()
    |> Repo.insert()
  end

  @doc """
  Gets `Omc.Payments.PaymentRequest` by `ref` if exists or nil.
  """
  @spec get_payment_request(binary()) :: %PaymentRequest{} | nil
  def get_payment_request(ref) when is_binary(ref) do
    PaymentRequest
    |> where(ref: ^ref)
    |> preload(:payment_states)
    |> Repo.one()
  end

  # def query_next_state(ref) when is_binary(ref) do
  #   ref
  #   |> get_payment_request()
  # |> then(& &1.payment_states)
  #   |> List.last()
  #   |> then(& &1.state)
  #   |> case do
  #     :pending ->
  #       
  #   end
  #   
  # end
end
