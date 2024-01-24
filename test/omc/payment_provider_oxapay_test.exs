defmodule Omc.PaymentProviderOxapayTest do
  alias Omc.Payments.PaymentProviderOxapay
  alias Omc.TeslaMock
  use Omc.DataCase, aync: true
  import Mox

  setup %{} do
    %{
      merchant: Application.get_env(:omc, :ipgs)[:oxapay][:api_key]
    }
  end

  describe "send_payment_request/1" do
    setup %{} do
      %{
        req_url: Application.get_env(:omc, :ipgs)[:oxapay][:base_url] <> "/request"
      }
    end

    test "ok request", %{req_url: req_url, merchant: merchant} do
      req_body_json =
        %{
          merchant: merchant,
          amount: 5.0,
          currency: "USD",
          lifeTime: Application.get_env(:omc, :ipgs)[:oxapay][:timeout],
          callbackUrl:
            Application.get_env(:omc, :ipgs)[:callback_base_url] <> "/api/payment/oxapay",
          returnUrl: Application.get_env(:omc, :ipgs)[:return_url],
          email: "123456789" <> "@" <> "telegram"
        }
        |> Jason.encode!()

      TeslaMock
      |> expect(:call, fn %{method: :post, url: ^req_url, body: ^req_body_json}, _opts ->
        {:ok,
         %{
           status: 200,
           body: %{
             "result" => 100,
             "message" => "some success message",
             "trackId" => "12345",
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
                    "trackId" => "12345"
                  },
                  type: :push,
                  ref: "12345",
                  url: "https://example.com/pay_please"
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
             "trackId" => "12345",
             "payLink" => "https://example.com/pay_please"
           }
         }}
      end)

      assert PaymentProviderOxapay.send_payment_request(%{
               user_id: "123456789",
               user_type: :telegram,
               money: Money.new(500, :USD)
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
      data = %{
        "status" => "",
        "trackId" => "123456789",
        "amount" => "100",
        "currency" => "USDT",
        "email" => "12341234123@telegram",
        "date" => "1698107946",
        "type" => "payment"
      }

      %{data: data}
    end

    test "paid callback", %{data: data} do
      data = data |> Map.put("status", "Paid")
      body = data |> Jason.encode!()
      hmac = PaymentProviderOxapay.hmac(body)

      assert {:ok, %{state: :done, ref: "123456789", data: ^data}, "OK"} =
               PaymentProviderOxapay.callback(%{params: %{"hmac" => hmac}, body: body})
    end

    test "Expired callback", %{data: data} do
      data = data |> Map.put("status", "Expired")
      body = data |> Jason.encode!()
      hmac = PaymentProviderOxapay.hmac(body)

      assert {:ok, %{state: :failed, ref: "123456789", data: ^data}, "OK"} =
               PaymentProviderOxapay.callback(%{params: %{"hmac" => hmac}, body: body})
    end

    test "Failed callback", %{data: data} do
      data = data |> Map.put("status", "Failed")
      body = data |> Jason.encode!()
      hmac = PaymentProviderOxapay.hmac(body)

      assert {:ok, %{state: :failed, ref: "123456789", data: ^data}, "OK"} =
               PaymentProviderOxapay.callback(%{params: %{"hmac" => hmac}, body: body})
    end

    test "Confirming callback", %{data: data} do
      data = data |> Map.put("status", "Confirming")
      body = data |> Jason.encode!()
      hmac = PaymentProviderOxapay.hmac(body)

      assert {:ok, %{state: :pending, ref: "123456789", data: ^data}, "OK"} =
               PaymentProviderOxapay.callback(%{params: %{"hmac" => hmac}, body: body})
    end

    test "Waiting callback", %{data: data} do
      data = data |> Map.put("status", "Waiting")
      body = data |> Jason.encode!()
      hmac = PaymentProviderOxapay.hmac(body)

      assert {:ok, %{state: :pending, ref: "123456789", data: ^data}, "OK"} =
               PaymentProviderOxapay.callback(%{params: %{"hmac" => hmac}, body: body})
    end

    test "New callback", %{data: data} do
      data = data |> Map.put("status", "New")
      body = data |> Jason.encode!()
      hmac = PaymentProviderOxapay.hmac(body)

      assert {:ok, %{state: :pending, ref: "123456789", data: ^data}, "OK"} =
               PaymentProviderOxapay.callback(%{params: %{"hmac" => hmac}, body: body})
    end

    test "non valid status", %{data: data} do
      data = data |> Map.put("status", "Others")
      body = data |> Jason.encode!()
      hmac = PaymentProviderOxapay.hmac(body)

      assert {:error, "NOK"} =
               PaymentProviderOxapay.callback(%{params: %{"hmac" => hmac}, body: body})
    end

    test "non valid hmac", %{data: data} do
      data = data |> Map.put("status", "New")
      body = data |> Jason.encode!()

      assert {:error, "NOK"} =
               PaymentProviderOxapay.callback(%{
                 params: %{"hmac" => "some value"},
                 body: body
               })
    end
  end

  describe "send_state_inquiry_request/1" do
    setup %{} do
      inq_url = Application.get_env(:omc, :ipgs)[:oxapay][:base_url] <> "/inquiry"
      %{inq_url: inq_url}
    end

    test "ok request", %{inq_url: inq_url, merchant: merchant} do
      req_body_json = %{trackId: "12345", merchant: merchant} |> Jason.encode!()

      TeslaMock
      |> expect(:call, fn %{method: :post, url: ^inq_url, body: ^req_body_json}, _opts ->
        {:ok,
         %{
           status: 200,
           body: %{
             "result" => 100,
             "message" => "some success message",
             "trackId" => "12345",
             "status" => "Waiting"
           }
         }}
      end)

      assert PaymentProviderOxapay.send_state_inquiry_request("12345") ==
               {:ok,
                %{
                  state: :pending,
                  data: %{
                    "result" => 100,
                    "message" => "some success message",
                    "trackId" => "12345",
                    "status" => "Waiting"
                  }
                }}
    end

    test "non 100 result code", %{inq_url: inq_url, merchant: merchant} do
      req_body_json = %{trackId: "12345", merchant: merchant} |> Jason.encode!()

      TeslaMock
      |> expect(:call, fn %{method: :post, url: ^inq_url, body: ^req_body_json}, _opts ->
        {:ok,
         %{
           status: 200,
           body: %{
             "result" => 101,
             "message" => "some error message"
           }
         }}
      end)

      assert PaymentProviderOxapay.send_state_inquiry_request("12345") ==
               {:error,
                %{
                  error_code: 101,
                  error_message: "some error message"
                }}
    end

    test "non 200 status code", %{inq_url: inq_url, merchant: merchant} do
      req_body_json = %{trackId: "12345", merchant: merchant} |> Jason.encode!()

      TeslaMock
      |> expect(:call, fn %{method: :post, url: ^inq_url, body: ^req_body_json}, _opts ->
        {:ok, %{status: 404, body: %{}}}
      end)

      assert PaymentProviderOxapay.send_state_inquiry_request("12345") ==
               {:error, :something_wrong}
    end
  end

  describe "get_paid_money!/2" do
    test "success case" do
      data = %{
        "currency" => "USD",
        "rate" => "9.25",
        "payAmount" => "18.5",
        "payCurrency" => "TRX"
      }

      assert Money.new(200, :USD) == PaymentProviderOxapay.get_paid_money!(data, :USD)
    end

    test "mismactch curreny causes a raise" do
      data = %{
        "currency" => "EUR",
        "rate" => "9.1234",
        "payAmount" => "970",
        "payCurrency" => "TRX"
      }

      assert_raise(RuntimeError, fn ->
        PaymentProviderOxapay.get_paid_money!(data, :USD)
      end)
    end
  end

  describe "get_paid_ref/1" do
    test "success case" do
      refute PaymentProviderOxapay.get_paid_ref(%{
               "trackId" => 123_456_789,
               "other_field" => "other_field_value"
             })
    end
  end
end
