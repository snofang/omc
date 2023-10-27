defmodule Omc.Payments do
  alias Omc.Payments.{PaymentRequest, PaymentState}
  alias Omc.Payments.PaymentProvider
  import Ecto.Query
  alias Omc.Repo

  def create_payment_request(ipg, %{user_id: user_id, user_type: user_type, money: money}) do
    ref = Ecto.UUID.generate()

    PaymentProvider.send_paymet_request(ipg, %{money: money, ref: ref})
    |> case do
      {:ok, payment_url} ->
        PaymentRequest.create_changeset(%{
          user_id: user_id,
          user_type: user_type,
          money: money,
          ref: ref,
          ipg: ipg,
          type: ipg_type(ipg),
          url: payment_url
        })
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
            {:error, PaymentProvider.not_found_response(ipg)}

          request ->
            {:ok, _state} = insert_payment_state(request, state_attrs)
            {:ok, res}
        end

      {:error, res} ->
        {:error, res}
    end
  end

  # prevents multiple state with same state value
  # note: it does not completely prevent multiple rows with same sate, but those situations are rare
  # and it doesn't matter if more than one record exist for one state
  defp insert_payment_state(payment_request, %{state: state} = attrs) do
    payment_state = payment_request.payment_states |> Enum.find(&(&1.state == state))

    if payment_state do
      {:ok, payment_state}
    else
      attrs
      |> Map.put(:payment_request_id, payment_request.id)
      |> PaymentState.create_changeset()
      |> Repo.insert()
    end
  end

  @doc """
  Gets `Omc.Payments.PaymentRequest` by `ref` if exists or nil.
  """
  @spec get_payment_request(binary()) :: %PaymentRequest{} | nil
  def get_payment_request(ref) do
    PaymentRequest
    |> where(ref: ^ref)
    |> preload(:payment_states)
    |> Repo.one()
  end

  defp ipg_type(ipg) when is_atom(ipg) do
    Application.get_env(:omc, :ipgs)[ipg][:type]
  end
end
