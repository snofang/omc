defmodule Omc.Payments.PaymentProviderNowpayments do
  # TODO: this is a draft and will be continued later
  @doc """
  This is just a tryout for NowPayments and is not complete; considered as draft.
  Currently even the `inquiry` function is just a copy and paste and doesn't contain 
  any meaningful; The problem which caused not continuing this, is the logic behind nowpayments;
  It accepts any number of repetitive payments for a given payment link and generate a new paymentId 
  for it. It means there is no end for a given payment, which is not well suited here. 
  """
  alias Omc.Payments.PaymentProvider
  use PaymentProvider, :nowpayments
  require Logger
  use Tesla, only: [:post, :get]
  plug(Tesla.Middleware.BaseUrl, base_url())
  plug(Tesla.Middleware.JSON)
  plug(Tesla.Middleware.Headers, [{"x-api-key", api_key()}])

  @impl PaymentProvider
  def send_payment_request(
        %{ipg: :nowpayments, money: money, user_type: _user_type, user_id: _user_id} = attrs
      ) do
    post(
      "/invoice",
      %{
        price_amount: money |> Money.to_decimal() |> Decimal.to_float(),
        price_currency: to_string(money.currency) |> String.downcase(),
        ipn_callback_url: callback_url(),
        success_url: return_url(),
        cancel_url: return_url(),
        is_fixed_rate: false,
        is_fee_paid_by_user: false
      }
    )
    |> case do
      {:ok, %{body: data = %{"id" => invoice_id, "invoice_url" => invoice_url}}} ->
        {:ok,
         attrs
         |> Map.put(:data, data)
         |> Map.put(:ref, invoice_id |> to_string())
         |> Map.put(:url, invoice_url)
         |> Map.put(:type, :push)}

      result ->
        Logger.warning("Nowpayments payment request failure; response: #{inspect(result)}")
        {:error, :something_wrong}
    end
  end

  @impl PaymentProvider
  def callback(%{params: %{"x-nowpayments-sig" => hmac}, body: body}) do
    caculated_hmac =
      body
      |> Jason.decode!(objects: :ordered_objects)
      |> Jason.encode!()
      |> hmac()

    if(caculated_hmac == hmac |> String.downcase()) do
      callback(Jason.decode!(body))
    else
      {:error, "NOK"}
    end
  end

  def callback(data = %{"payment_status" => status, "invoice_id" => invoice_id})
      when status in [
             "waiting",
             "confirming",
             "confirmed",
             "sending",
             "partially_paid",
             "finished",
             "failed",
             "refunded",
             "expired"
           ] do
    {:ok, %{state: get_internal_state(status), ref: invoice_id |> to_string(), data: data}, "OK"}
  end

  def callback(_data) do
    {:error, "NOK"}
  end

  @impl PaymentProvider
  def send_state_inquiry_request(ref) do
    # |> String.to_integer()
    track_id = ref

    post(
      "/inquiry",
      %{
        merchant: api_key(),
        trackId: track_id
      }
    )
    |> case do
      {:ok, %{body: data = %{"result" => 100, "trackId" => ^track_id, "status" => status}}} ->
        {:ok, %{state: get_internal_state(status), data: data}}

      res = {:ok, %{body: %{"result" => result, "message" => message}}} ->
        Logger.info("Calling oxapay inquiry for ref=#{ref} failed; response is: #{inspect(res)}")

        {:error, %{error_code: result, error_message: message}}

      res ->
        Logger.info("Calling oxapay inquiry for ref=#{ref} failed; response is: #{inspect(res)}")

        {:error, :something_wrong}
    end
  end

  def get_internal_state(status) do
    case status do
      status when status in ["expired", "failed", "refunded"] ->
        :failed

      status when status in ["waiting", "confirming", "confirmed", "sending", "partially_paid"] ->
        :pending

      status when status in ["finished"] ->
        :done
    end
  end

  @impl PaymentProvider
  def get_paid_money!(%{} = data, currency) do
    if currency |> to_string() |> String.downcase() == data["price_currency"] |> String.downcase() do
      # data["price_amount"] * data["actually_paid"] / data["pay_amount"]
      data["price_amount"]
      |> Money.parse!(currency)
    else
      raise "currency mismatch: requested currency: #{currency}, paid currency: #{data["price_currency"]}"
    end
  end

  def hmac(data) when is_binary(data) do
    :crypto.mac(
      :hmac,
      :sha512,
      Application.get_env(:omc, :ipgs)[:nowpayments][:ipn_secret_key],
      data
    )
    |> :binary.encode_hex()
    |> String.downcase()
  end
end
