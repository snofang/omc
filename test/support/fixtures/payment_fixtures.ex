defmodule Omc.PaymentFixtures do
  alias Omc.Payments.PaymentRequest
  alias Omc.LedgersFixtures
  alias Omc.Payments
  alias Omc.PaymentProviderOxapayMock
  import Mox

  def payment_request_fixture(ipg \\ :oxapay, attrs \\ %{}) when is_atom(ipg) do
    PaymentProviderOxapayMock
    |> expect(:send_payment_request, fn attrs = %{ipg: _, money: _, user_type: _, user_id: _} ->
      ref = System.unique_integer([:positive])

      {:ok,
       attrs
       |> Map.put(:data, %{"some_data_key" => "some_data_key_value"})
       |> Map.put(:ref, ref |> Integer.to_string())
       |> Map.put(:url, "https://example.com/pay/" <> to_string(ref))
       |> Map.put(:type, :push)}
    end)

    Omc.TeslaMock
    |> expect(:call, fn _env, _opts -> %{} end)

    {:ok, payment_request} =
      Payments.create_payment_request(
        :oxapay,
        Enum.into(attrs, %{
          user_type: :telegram,
          user_id: LedgersFixtures.unique_user_id(),
          money: Money.new(10000)
        })
      )

    payment_request
  end

  def payment_state_by_callback_fixture(%PaymentRequest{} = payment_request, state)
      when is_atom(state) do
    PaymentProviderOxapayMock
    |> expect(:callback, fn _params, _body ->
      {:ok, %{state: state, ref: payment_request.ref, data: %{}}, :some_response}
    end)

    {:ok, :some_response} = Payments.callback(payment_request.ipg, %{}, nil)
  end

  def done_payment_request_fixture() do
    pr = payment_request_fixture()
    payment_state_by_callback_fixture(pr, :pending)
    payment_state_by_callback_fixture(pr, :pending)
    payment_state_by_callback_fixture(pr, :done)
    pr
  end
end
