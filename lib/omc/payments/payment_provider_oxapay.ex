defmodule Omc.Payments.PaymentProviderOxapay do
  alias Omc.Payments.PaymentProvider
  use PaymentProvider, :oxapay
  require Logger
  use Tesla, only: [:post, :get]
  plug(Tesla.Middleware.BaseUrl, base_url())
  plug(Tesla.Middleware.JSON)

  @impl PaymentProvider
  def send_payment_request(%{money: money, user_type: user_type, user_id: user_id}) do
    post(
      "/request",
      %{
        merchant: api_key(),
        amount: money |> Money.to_decimal() |> Decimal.to_float(),
        currency: to_string(money.currency),
        lifeTime: timeout(),
        callbackUrl: callback_url(),
        returnUrl: return_url(),
        email: user_id <> "@" <> to_string(user_type)
      }
    )
    |> case do
      {:ok, %{body: data = %{"result" => 100, "trackId" => track_id, "payLink" => pay_link}}} ->
        {:ok,
         %{
           data: data,
           ref: track_id,
           url: pay_link,
           type: :push
         }}

      result = {:ok, %{body: %{"result" => result_code}}} ->
        Logger.info("oxapay payment request failure; response: #{inspect(result)}")
        {:error, result_code}

      result ->
        Logger.info("oxapay payment request failure; response: #{inspect(result)}")
        {:error, :something_wrong}
    end
  end

  @impl PaymentProvider
  def callback(%{params: %{"hmac" => hmac}, body: body}) do
    if(hmac(body) == hmac |> String.downcase()) do
      callback(Jason.decode!(body))
    else
      {:error, "NOK"}
    end
  end

  def callback(data = %{"status" => status, "trackId" => ref})
      when status in ["Expired", "New", "Waiting", "Confirming", "Paid", "Failed"] do
    {:ok, %{state: get_internal_state(status), ref: ref, data: data}, "OK"}
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
      "Expired" ->
        :failed

      status when status in ["New", "Waiting", "Confirming"] ->
        :pending

      "Paid" ->
        :done

      "Failed" ->
        :failed
    end
  end

  @impl PaymentProvider
  def get_paid_money!(
        %{
          "payAmount" => pay_amount,
          "rate" => rate,
          "payCurrency" => _pay_currency,
          "currency" => currency
        },
        :USD
      ) do
    if "USD" == String.upcase(currency) do
      pay_amount
      |> Decimal.parse()
      |> then(fn {d, ""} -> d end)
      |> Decimal.div(Decimal.parse(rate) |> then(fn {r, ""} -> r end))
      |> Money.parse!(:USD)

      # get_paid_crypto_in_usd(pay_amount, pay_currency)
    else
      raise "currency mismatch: requested currency: USD, paid currency: #{currency}"
    end
  end

  @impl PaymentProvider
  def get_paid_ref(_data) do
    nil
  end

  def hmac(data) when is_binary(data) do
    :crypto.mac(:hmac, :sha512, Application.get_env(:omc, :ipgs)[:oxapay][:api_key], data)
    |> :binary.encode_hex()
    |> String.downcase()
  end
end
