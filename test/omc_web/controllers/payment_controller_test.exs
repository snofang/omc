defmodule OmcWeb.PaymentControllerTest do
  use OmcWeb.ConnCase, async: true
  alias Omc.PaymentProviderOxapayMock
  alias Omc.Payments.PaymentProviderOxapay
  import Omc.PaymentFixtures
  import Mox

  setup %{conn: conn} do
    PaymentProviderOxapayMock
    |> expect(:callback, fn params, body -> PaymentProviderOxapay.callback(params, body) end)

    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "callback for oxapay payment provider" do
    setup %{} do
      [payment_request: payment_request_fixture()]
    end

    test "not existing ref", %{conn: conn} do
      conn =
        post(
          conn,
          ~p"/api/payment/oxapay",
          %{
            "status" => "Waiting",
            "trackId" => "35092972",
            "amount" => "100",
            "currency" => "TRX",
            "type" => "payment"
          }
        )

      assert json_response(conn, 404) == "not_found"
    end

    test "success state update", %{conn: conn, payment_request: payment_request} do
      conn =
        post(
          conn,
          ~p"/api/payment/oxapay",
          %{
            "status" => "Waiting",
            "trackId" => payment_request.ref,
            "amount" => "100",
            "currency" => "TRX",
            "type" => "payment"
          }
        )

      assert json_response(conn, 200) == "OK"
    end
  end
end
