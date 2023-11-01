defmodule Omc.Payments.PaymentProviderOxapay do
  alias Omc.Payments.PaymentProvider
  use PaymentProvider, :oxapay
  require Logger
  use Tesla, only: [:post, :get]
  plug(Tesla.Middleware.BaseUrl, base_url())
  plug(Tesla.Middleware.JSON)

  @impl PaymentProvider
  def send_payment_request(
        %{ipg: :oxapay, money: money, user_type: user_type, user_id: user_id} = attrs
      ) do
    post(
      "/request",
      %{
        merchant: api_key(),
        amount: money |> Money.to_decimal() |> Decimal.to_float(),
        currency: to_string(money.currency),
        lifeTime: 30,
        callbackUrl: callback_url(),
        returnUrl: return_url(),
        email: user_id <> "@" <> to_string(user_type)
      }
    )
    |> case do
      {:ok, %{body: data = %{"result" => 100, "trackId" => track_id, "payLink" => pay_link}}} ->
        {:ok,
         attrs
         |> Map.put(:data, data)
         |> Map.put(:ref, track_id |> Integer.to_string())
         |> Map.put(:url, pay_link)
         |> Map.put(:type, :push)}

      result = {:ok, %{body: %{"result" => result_code}}} ->
        Logger.info("oxapay payment request failure; response: #{inspect(result)}")
        {:error, result_code}

      result ->
        Logger.info("oxapay payment request failure; response: #{inspect(result)}")
        {:error, :something_wrong}
    end
  end

  @impl PaymentProvider
  def callback(_params, data = %{"status" => "Paid", "trackId" => ref}) do
    {:ok, %{state: :done, ref: ref, data: data}, "OK"}
  end

  @impl PaymentProvider
  def callback(_params, data = %{"status" => status, "trackId" => ref})
      when status in ["Expired", "Failed"] do
    {:ok, %{state: :failed, ref: ref, data: data}, "OK"}
  end

  @impl PaymentProvider
  def callback(_params, data = %{"status" => status, "trackId" => ref})
      when status in ["New", "Waiting", "Confirming"] do
    {:ok, %{state: :pending, ref: ref, data: data}, "OK"}
  end

  @impl PaymentProvider
  def callback(_params, _data) do
    {:error, "NOK"}
  end

  @impl PaymentProvider
  def send_state_inquiry_request(%{money: _money, ref: ref}) do
    post("/confirm_payment",
      query: [
        api_key: api_key(),
        reference: ref
        # amount_irr: amount_str(money)
      ]
    )
    |> case do
      {:ok, %{body: %{"ok" => true, "result" => result = %{"state" => "paid"}}}} ->
        {:ok, {:completed, result}}

      {:ok, %{body: %{"ok" => false, "error" => error_key}}} ->
        {:error, error_key}

      _result ->
        {:error, :something_wrong}
    end
  end
end
