defmodule Omc.PaymentProviderNowpaymentsTest do
  alias Omc.Payments.PaymentProviderNowpayments
  alias Omc.TeslaMock
  use Omc.DataCase, aync: true
  import Mox

  setup %{} do
    %{
      api_key: Application.get_env(:omc, :ipgs)[:nowpayments][:api_key],
      callback_url:
        Application.get_env(:omc, :ipgs)[:callback_base_url] <> "/api/payment/nowpayments",
      return_url: Application.get_env(:omc, :ipgs)[:return_url],
      req_url: Application.get_env(:omc, :ipgs)[:nowpayments][:base_url] <> "/invoice"
    }
  end

  describe "send_payment_request/1" do
    test "ok request", %{
      req_url: req_url,
      api_key: api_key,
      callback_url: callback_url,
      return_url: return_url
    } do
      TeslaMock
      |> expect(:call, fn %{
                            method: :post,
                            url: ^req_url,
                            body: request_body,
                            headers: [
                              {"content-type", "application/json"},
                              {"x-api-key", ^api_key}
                            ]
                          },
                          [] = _opts ->
        assert %{
                 "price_amount" => 5.0,
                 "price_currency" => "USD",
                 "ipn_callback_url" => ^callback_url,
                 "success_url" => ^return_url,
                 "cancel_url" => ^return_url,
                 "is_fixed_rate" => false,
                 "is_fee_paid_by_user" => false
               } = Jason.decode!(request_body)

        {:ok,
         %{
           status: 200,
           body: %{
             "id" => 12345,
             "invoice_url" => "https://example.com/pay_please",
             "other_field" => "other_field_value"
           }
         }}
      end)

      assert PaymentProviderNowpayments.send_payment_request(%{
               user_id: "123456789",
               user_type: :telegram,
               money: Money.new(500, :USD)
             }) ==
               {:ok,
                %{
                  data: %{
                    "id" => 12345,
                    "invoice_url" => "https://example.com/pay_please",
                    "other_field" => "other_field_value"
                  },
                  type: :push,
                  ref: "12345",
                  url: "https://example.com/pay_please"
                }}
    end

    test "non 200 response status code", %{req_url: req_url} do
      # TODO: to assert for warning log message
      Omc.TeslaMock
      |> expect(:call, fn %{method: :post, url: ^req_url}, _opts ->
        {:ok,
         %{
           status: 404,
           body: %{}
         }}
      end)

      assert PaymentProviderNowpayments.send_payment_request(%{
               user_id: "123456789",
               user_type: :telegram,
               money: Money.new(500, :USD)
             }) ==
               {:error, :something_wrong}
    end
  end

  describe "callback/1" do
    test "state mapping check" do
      assert_callback_state("waiting", :pending)
      assert_callback_state("confirming", :pending)
      assert_callback_state("confirmed", :pending)
      assert_callback_state("sending", :pending)
      assert_callback_state("partially_paid", :done)
      assert_callback_state("finished", :done)
      assert_callback_state("failed", :failed)
      assert_callback_state("refunded", :failed)
      assert_callback_state("expired", :failed)
    end

    test "non valid status" do
      data = %{
        "payment_status" => "other",
        "invoice_id" => 123_456_789
      }

      {body, hmac} = body_hmac(data)

      assert {:error, "NOK"} =
               PaymentProviderNowpayments.callback(%{
                 params: %{"x-nowpayments-sig" => hmac},
                 body: body
               })
    end

    test "non valid hmac" do
      data = %{
        "payment_status" => "finished",
        "invoice_id" => 123_456_789
      }

      {body, _hmac} = body_hmac(data)

      assert {:error, "NOK"} =
               PaymentProviderNowpayments.callback(%{
                 params: %{"x-nowpayments-sig" => "some_value"},
                 body: body
               })
    end
  end

  describe "send_state_inquiry_request/1" do
    test "not supported in nowpayments" do
      assert PaymentProviderNowpayments.send_state_inquiry_request("12345") ==
               {:error, :not_supported}
    end
  end

  describe "get_paid_money!/2" do
    test "success case" do
      TeslaMock
      |> expect(
        :call,
        fn %Tesla.Env{
             method: :get,
             url: "https://api.binance.com/api/v3/avgPrice",
             query: [symbol: "TRXUSDT"],
             headers: [],
             body: nil,
             status: nil,
             opts: []
           },
           [] = _opts ->
          {:ok,
           %{
             status: 200,
             body: %{"mins" => 5, "price" => "0.10425122", "closeTime" => 1_703_155_016_256}
           }}
        end
      )

      paid_data = %{"price_currency" => "usd", "pay_amount" => 10, "pay_currency" => "trx"}
      expected_money = Decimal.mult("10", "0.10425122") |> Money.parse!(:USD)
      assert expected_money == PaymentProviderNowpayments.get_paid_money!(paid_data, :USD)
    end

    test "mismactch curreny causes a raise" do
      paid_data = %{"price_currency" => "eur", "pay_amount" => 10, "pay_currency" => "trx"}

      assert_raise(RuntimeError, fn ->
        PaymentProviderNowpayments.get_paid_money!(paid_data, :USD)
      end)
    end

    test "getting price invalid symbol failure" do
      TeslaMock
      |> expect(
        :call,
        fn %Tesla.Env{
             method: :get,
             url: "https://api.binance.com/api/v3/avgPrice"
           },
           _opts ->
          {:ok,
           %{
             status: 200,
             body: %{"code" => -1121, "msg" => "Invalid symbol."}
           }}
        end
      )

      paid_data = %{"price_currency" => "usd", "pay_amount" => 10, "pay_currency" => "trx"}

      assert_raise(MatchError, fn ->
        PaymentProviderNowpayments.get_paid_money!(paid_data, :USD)
      end)
    end
  end

  describe "get_paid_ref/1" do
    test "success case" do
      assert "123456789" =
               PaymentProviderNowpayments.get_paid_ref(%{
                 "payment_id" => 123_456_789,
                 "other_field" => "other_field_value"
               })
    end
  end

  defp assert_callback_state(state_in, state_out) do
    data = %{
      "payment_status" => state_in,
      "invoice_id" => 123_456_789
    }

    {body, hmac} = body_hmac(data)

    assert {:ok, %{state: ^state_out, ref: "123456789", data: ^data}, "OK"} =
             PaymentProviderNowpayments.callback(%{
               params: %{"x-nowpayments-sig" => hmac},
               body: body
             })
  end

  defp body_hmac(data) do
    body = Jason.encode!(data)

    {body,
     body
     |> Jason.decode!(objects: :ordered_objects)
     |> Jason.encode!()
     |> PaymentProviderNowpayments.hmac()}
  end
end
