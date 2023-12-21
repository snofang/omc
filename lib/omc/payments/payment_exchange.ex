defmodule Omc.Payments.PaymentExchange do
  require Logger
  use Tesla, only: [:get]
  plug(Tesla.Middleware.BaseUrl, "https://api.binance.com/api/v3")
  plug(Tesla.Middleware.JSON)

  def get_avg_price_in_usdt("USDT"), do: {:ok, Decimal.new(1)}
  def get_avg_price_in_usdt("usdt"), do: {:ok, Decimal.new(1)}

  def get_avg_price_in_usdt(symbol) do
    case get("/avgPrice", query: [symbol: String.upcase(symbol) <> "USDT"]) do
      {:ok, %{body: %{"price" => price}}} ->
        case Decimal.parse(price) do
          {decimal, _} ->
            {:ok, decimal}

          :error ->
            {:error, :bad_argument}
        end

      any ->
        Logger.warn(
          "failed to get Binance avg price for symbol: #{inspect(symbol)}, result: #{inspect(any)}"
        )

        {:error, :failed_getting_price}
    end
  end
end
