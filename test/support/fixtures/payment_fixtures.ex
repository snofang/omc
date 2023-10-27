defmodule Omc.PaymentFixtures do
  alias Omc.LedgersFixtures
  alias Omc.Payments
  alias Omc.PaymentProviderWpMock
  import Mox

  def payment_request_fixture(ipg \\ :wp, attrs \\ %{}) when is_atom(ipg) do
    PaymentProviderWpMock
    |> expect(:send_payment_request, fn %{money: _, ref: _} ->
      {:ok, OmcWeb.Endpoint.url() <> "/api/payment/" <> to_string(ipg)}
    end)

    {:ok, payment_request} =
      Payments.create_payment_request(
        :wp,
        Enum.into(attrs, %{
          user_type: :telegram,
          user_id: LedgersFixtures.unique_user_id(),
          money: Money.new(10000)
        })
      )

    payment_request
  end
end
