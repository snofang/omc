defmodule Omc.PaymentProviderWp do
  alias Omc.Payments.PaymentProviderWp
  use Omc.DataCase, aync: true
  import Tesla.Mock

  describe "send_payment_request/1" do
    test "ok request" do
      ref = Ecto.UUID.generate()
      payment_url = "https://example.com/pay_please"
      callback_url = OmcWeb.Endpoint.url() <> "/api/payment/wp"

      mock(fn
        %{
          method: :get,
          url: "https://example.com/api/create_request",
          query: [
            api_key: "api_key_example",
            reference: ^ref,
            amount_irr: "123",
            callback_url: ^callback_url
          ]
        } ->
          %Tesla.Env{
            status: 200,
            body: %{
              "ok" => true,
              "result" => %{"payment_url" => payment_url}
            }
          }
      end)

      assert PaymentProviderWp.send_payment_request(%{money: Money.new(12345), ref: ref}) ==
               {:ok, payment_url}
    end

    test "some logical error" do
      ref = Ecto.UUID.generate()

      mock(fn
        %{
          method: :get,
          url: "https://example.com/api/create_request"
        } ->
          %Tesla.Env{
            status: 200,
            body: %{
              "ok" => false,
              "error" => "INVALID_API_CALL"
            }
          }
      end)

      assert PaymentProviderWp.send_payment_request(%{money: Money.new(12345), ref: ref}) ==
               {:error, "INVALID_API_CALL"}
    end

    test "non 200 response status code" do
      ref = Ecto.UUID.generate()

      mock(fn
        %{
          method: :get,
          url: "https://example.com/api/create_request"
        } ->
          %Tesla.Env{
            status: 404
          }
      end)

      assert PaymentProviderWp.send_payment_request(%{money: Money.new(12345), ref: ref}) ==
               {:error, :something_wrong}
    end
  end
end
