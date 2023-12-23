defmodule Omc.Payments.PaymentProviderNowpayments do
  alias Omc.Payments.PaymentProvider
  use PaymentProvider, :nowpayments
  require Logger
  use Tesla, only: [:post, :get]
  plug(Tesla.Middleware.BaseUrl, base_url())
  plug(Tesla.Middleware.JSON)
  plug(Tesla.Middleware.Headers, [{"x-api-key", api_key()}])

  @impl PaymentProvider
  def send_payment_request(%{money: money, user_type: _user_type, user_id: _user_id}) do
    post(
      "/invoice",
      %{
        price_amount: money |> Money.to_decimal() |> Decimal.to_float(),
        price_currency: to_string(money.currency),
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
         %{
           data: data,
           ref: invoice_id |> to_string(),
           url: invoice_url,
           type: :push
         }}

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
  def send_state_inquiry_request(_ref) do
    {:error, :not_supported}
  end

  def get_internal_state(status) do
    case status do
      status when status in ["expired", "failed", "refunded"] ->
        :failed

      status when status in ["waiting", "confirming", "confirmed", "sending"] ->
        :pending

      status when status in ["finished", "partially_paid"] ->
        :done
    end
  end

  @impl PaymentProvider
  def get_paid_money!(
        %{
          "price_amount" => price_amount,
          "price_currency" => price_currency,
          "pay_amount" => pay_amount,
          "actually_paid" => actually_paid,
          "pay_currency" => _pay_currency
        } = data,
        :USD
      ) do
    if "USD" == price_currency |> String.upcase() do
      # Note: this is for dev tesitng purpose and because 
      # NowPayments returns zero in `actually_paid` in sandbox environment.
      if(base_url() =~ "sandbox") do
        # get_paid_crypto_in_usd(pay_amount, pay_currency)
        Money.parse!(price_amount, :USD)
      else
        # get_paid_crypto_in_usd(actually_paid, pay_currency)
        Money.parse!(price_amount / pay_amount * actually_paid, :USD)
      end
    else
      raise "currency mismatch: requested currency: USD, paid currency: #{data["price_currency"]}"
    end
  end

  @impl PaymentProvider
  def get_paid_ref(%{"payment_id" => payment_id}) do
    payment_id |> to_string()
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
