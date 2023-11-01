defmodule Omc.PaymentProviderOxapayTest do
  alias Omc.Payments.PaymentProviderOxapay
  use Omc.DataCase, aync: true
  import Mox

  setup %{} do
    req_url = Application.get_env(:omc, :ipgs)[:oxapay][:base_url] <> "/request"
    %{req_url: req_url}
  end

  describe "send_payment_request/1" do
    test "ok request", %{req_url: req_url} do
      req_body = %{
        merchant: Application.get_env(:omc, :ipgs)[:oxapay][:api_key],
        amount: 5.0,
        currency: "USD",
        lifeTime: Application.get_env(:omc, :ipgs)[:oxapay][:timeout],
        callbackUrl: OmcWeb.Endpoint.url() <> "/api/payment/oxapay",
        returnUrl: Application.get_env(:omc, :ipgs)[:return_url],
        email: "123456789" <> "@" <> "telegram"
      }

      req_body_json = Jason.encode!(req_body)

      Omc.TeslaMock
      |> expect(:call, fn %{method: :post, url: ^req_url, body: ^req_body_json}, _opts ->
        {:ok,
         %{
           status: 200,
           body: %{
             "result" => 100,
             "message" => "some success message",
             "trackId" => 12345,
             "payLink" => "https://example.com/pay_please"
           }
         }}
      end)

      assert PaymentProviderOxapay.send_payment_request(%{
               user_id: "123456789",
               user_type: :telegram,
               money: Money.new(500, :USD),
               ipg: :oxapay
             }) ==
               {:ok,
                %{
                  data: %{
                    "message" => "some success message",
                    "payLink" => "https://example.com/pay_please",
                    "result" => 100,
                    "trackId" => 12345
                  },
                  ipg: :oxapay,
                  type: :push,
                  money: %Money{amount: 500, currency: :USD},
                  ref: "12345",
                  url: "https://example.com/pay_please",
                  user_id: "123456789",
                  user_type: :telegram
                }}
    end

    test "some logical error", %{req_url: req_url} do
      Omc.TeslaMock
      |> expect(:call, fn %{method: :post, url: ^req_url}, _opts ->
        {:ok,
         %{
           status: 200,
           body: %{
             "result" => 101,
             "message" => "some error happend",
             "trackId" => 12345,
             "payLink" => "https://example.com/pay_please"
           }
         }}
      end)

      assert PaymentProviderOxapay.send_payment_request(%{
               user_id: "123456789",
               user_type: :telegram,
               money: Money.new(500, :USD),
               ipg: :oxapay
             }) ==
               {:error, 101}
    end

    test "non 200 response status code", %{req_url: req_url} do
      Omc.TeslaMock
      |> expect(:call, fn %{method: :post, url: ^req_url}, _opts ->
        {:ok,
         %{
           status: 404,
           body: %{}
         }}
      end)

      assert PaymentProviderOxapay.send_payment_request(%{
               user_id: "123456789",
               user_type: :telegram,
               money: Money.new(500, :USD),
               ipg: :oxapay
             }) ==
               {:error, :something_wrong}
    end
  end

  describe "callback/1" do
    setup %{} do
      %{
        data: %{
          "status" => "",
          "trackId" => "123456789",
          "amount" => "100",
          "currency" => "USDT",
          "email" => "12341234123@telegram",
          "date" => "1698107946",
          "type" => "payment"
        }
      }
    end

    test "paid callback", %{data: data} do
      body = data |> Map.put("status", "Paid")

      assert {:ok, %{state: :done, ref: "123456789", data: ^body}, "OK"} =
               PaymentProviderOxapay.callback(
                 nil,
                 body
               )
    end

    test "Expired callback", %{data: data} do
      body = data |> Map.put("status", "Expired")

      assert {:ok, %{state: :failed, ref: "123456789", data: ^body}, "OK"} =
               PaymentProviderOxapay.callback(
                 nil,
                 body
               )
    end

    test "Failed callback", %{data: data} do
      body = data |> Map.put("status", "Failed")

      assert {:ok, %{state: :failed, ref: "123456789", data: ^body}, "OK"} =
               PaymentProviderOxapay.callback(
                 nil,
                 body
               )
    end

    test "Confirming callback", %{data: data} do
      body = data |> Map.put("status", "Confirming")

      assert {:ok, %{state: :pending, ref: "123456789", data: ^body}, "OK"} =
               PaymentProviderOxapay.callback(
                 nil,
                 body
               )
    end

    test "Waiting callback", %{data: data} do
      body = data |> Map.put("status", "Waiting")

      assert {:ok, %{state: :pending, ref: "123456789", data: ^body}, "OK"} =
               PaymentProviderOxapay.callback(
                 nil,
                 body
               )
    end

    test "New callback", %{data: data} do
      body = data |> Map.put("status", "New")

      assert {:ok, %{state: :pending, ref: "123456789", data: ^body}, "OK"} =
               PaymentProviderOxapay.callback(
                 nil,
                 body
               )
    end

    test "non valid status", %{data: data} do
      body = data |> Map.put("status", "Others")

      assert {:error, "NOK"} =
               PaymentProviderOxapay.callback(
                 nil,
                 body
               )
    end
  end

  #
  # describe "send_state_inquiry_request/1" do
  #   test "ok request" do
  #     ref = Ecto.UUID.generate()
  #
  #     mock(fn
  #       %{
  #         method: :get,
  #         url: "https://example.com/api/confirm_payment",
  #         query: [
  #           api_key: "api_key_example",
  #           reference: ^ref,
  #           amount_irr: "123"
  #         ]
  #       } ->
  #         %Tesla.Env{
  #           status: 200,
  #           body: %{
  #             "ok" => true,
  #             "result" => %{
  #               "state" => "paid",
  #               "field1" => "field1_value",
  #               "field2" => "field2_value"
  #             }
  #           }
  #         }
  #     end)
  #
  #     assert PaymentProviderWp.send_state_inquiry_request(%{money: Money.new(12345), ref: ref}) ==
  #              {:ok,
  #               {:completed,
  #                %{"state" => "paid", "field1" => "field1_value", "field2" => "field2_value"}}}
  #   end
  #
  #   test "some logical error" do
  #     ref = Ecto.UUID.generate()
  #
  #     mock(fn
  #       %{
  #         method: :get,
  #         url: "https://example.com/api/confirm_payment"
  #       } ->
  #         %Tesla.Env{
  #           status: 200,
  #           body: %{
  #             "ok" => false,
  #             "error" => "INVALID_API_CALL"
  #           }
  #         }
  #     end)
  #
  #     assert PaymentProviderWp.send_state_inquiry_request(%{money: Money.new(12345), ref: ref}) ==
  #              {:error, "INVALID_API_CALL"}
  #   end
  #
  #   test "non 200 response status code" do
  #     ref = Ecto.UUID.generate()
  #
  #     mock(fn
  #       %{
  #         method: :get,
  #         url: "https://example.com/api/confirm_payment"
  #       } ->
  #         %Tesla.Env{
  #           status: 404
  #         }
  #     end)
  #
  #     assert PaymentProviderWp.send_state_inquiry_request(%{money: Money.new(12345), ref: ref}) ==
  #              {:error, :something_wrong}
  #   end
  # end
end
