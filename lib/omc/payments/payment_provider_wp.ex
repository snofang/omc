defmodule Omc.Payments.PaymentProviderWp do
  require Logger
  alias Omc.Payments.PaymentProvider
  @behaviour PaymentProvider
  use Tesla, only: [:get]
  plug(Tesla.Middleware.BaseUrl, Application.get_env(:omc, :ipgs)[:wp][:base_url])
  plug(Tesla.Middleware.JSON)

  def send_payment_request(%{money: money, ref: ref}) do
    get("/create_request",
      query: [
        api_key: api_key(),
        reference: ref,
        amount_irr: amount_str(money),
        callback_url: OmcWeb.Endpoint.url() <> "/api/payment/wp"
      ]
    )
    |> case do
      {:ok, %{body: %{"ok" => true, "result" => %{"payment_url" => payment_url}}}} ->
        {:ok, payment_url}

      {:ok, %{body: %{"ok" => false, "error" => error_key}}} ->
        {:error, error_key}

      _result ->
        {:error, :something_wrong}
    end
  end

  def api_key(), do: Application.get_env(:omc, :ipgs)[:wp][:api_key]

  def amount_str(money) do
    money |> Money.to_decimal() |> Decimal.round() |> Decimal.to_string()
  end

  def app_base_url() do
    Application.get_env(:omc, :ipgs)[:app_endpoint]
  end

  def callback(%{"reference" => ref, "state" => "wait_for_confirm"}, _body) do
    %{state: :pending, ref: ref, res: %{ok: true}}
  end

  def callback(
        %{
          "reference" => ref,
          "state" => "error",
          "error_key" => error_key,
          "error_message" => error_message
        },
        _body
      ) do
    %{
      state: :cancelled,
      data: %{state: :error, error_key: error_key, error_message: error_message},
      ref: ref,
      res: %{ok: true}
    }
  end

  def callback(
        params = %{
          "reference" => _,
          "state" => _,
          "error_key" => _
        },
        body
      ) do
    callback(params |> Map.put("error_message", nil), body)
  end
end
