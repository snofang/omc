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
          callbackUrl: OmcWeb.Endpoint.url() <> "/api/payment/oxapay",
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

  describe "send_state_inquiry_request/1" do
    setup %{} do
      inq_url = Application.get_env(:omc, :ipgs)[:oxapay][:base_url] <> "/inquiry"
      %{inq_url: inq_url}
    end

    test "ok request", %{inq_url: inq_url, merchant: merchant} do
      req_body_json = %{trackId: 12345, merchant: merchant} |> Jason.encode!()

      TeslaMock
      |> expect(:call, fn %{method: :post, url: ^inq_url, body: ^req_body_json}, _opts ->
        {:ok,
         %{
           status: 200,
           body: %{
             "result" => 100,
             "message" => "some success message",
             "trackId" => 12345,
             "status" => "Waiting"
           }
         }}
      end)

      assert PaymentProviderOxapay.send_state_inquiry_request("12345") ==
               {:ok,
                %{
                  state: :pending,
                  ref: "12345",
                  data: %{
                    "result" => 100,
                    "message" => "some success message",
                    "trackId" => 12345,
                    "status" => "Waiting"
                  }
                }}
    end

    test "non 100 result code", %{inq_url: inq_url, merchant: merchant} do
      req_body_json = %{trackId: 12345, merchant: merchant} |> Jason.encode!()

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
      req_body_json = %{trackId: 12345, merchant: merchant} |> Jason.encode!()

      TeslaMock
      |> expect(:call, fn %{method: :post, url: ^inq_url, body: ^req_body_json}, _opts ->
        {:ok, %{status: 404, body: %{}}}
      end)

      assert PaymentProviderOxapay.send_state_inquiry_request("12345") ==
               {:error, :something_wrong}
    end
  end
end
