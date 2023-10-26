defmodule Omc.Payments do
  alias Omc.Payments.PaymentState
  alias Omc.Payments.PaymentRequest
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

  def callback(ipg, params, body) do
    state_attrs =
      %{ref: ref, res: res, state: _state} = PaymentProvider.callback(ipg, params, body)

    get_payment_request(ref)
    |> case do
      nil ->
        {:error, :not_found}

      request ->
        {:ok, _state} = insert_payment_state(request, state_attrs)
        {:ok, res}
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

  defp get_payment_request(ref) do
    PaymentRequest
    |> where(ref: ^ref)
    |> preload(:payment_states)
    |> Repo.one()
  end

  defp ipg_type(ipg) when is_atom(ipg) do
    Application.get_env(:omc, :ipgs)[ipg][:type]
  end
end
