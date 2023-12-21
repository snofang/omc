defmodule OmcWeb.PaymentControllerTest do
  use OmcWeb.ConnCase, async: true
  alias Omc.PaymentProviderMock
  alias Omc.Payments.PaymentProviderOxapay
  import Omc.PaymentFixtures
  import Mox

  setup %{conn: conn} do
    PaymentProviderMock
    |> expect(:callback, fn data = %{params: %{"hmac" => _hmac}, body: _body} ->
      PaymentProviderOxapay.callback(data)
    end)

    {:ok, conn: conn |> put_req_header("content-type", "application/json")}
  end

  describe "callback for oxapay payment provider" do
    setup %{} do
      [payment_request: payment_request_fixture()]
    end

    test "not existing ref", %{conn: conn} do
      body = %{
        "status" => "Waiting",
        "trackId" => "35092972",
        "amount" => "100",
        "currency" => "TRX",
        "type" => "payment"
      }

      body_raw = body |> Jason.encode!()

      conn =
        conn
        |> put_req_header("hmac", PaymentProviderOxapay.hmac(body_raw))
        |> post(~p"/api/payment/oxapay", body_raw)

      assert(json_response(conn, 404) == "not_found")
    end

    test "success state update", %{conn: conn, payment_request: payment_request} do
      body = %{
        "status" => "Waiting",
        "trackId" => payment_request.ref,
        "amount" => "100",
        "currency" => "TRX",
        "type" => "payment"
      }

      body_raw = Jason.encode!(body)

      conn =
        conn
        |> put_req_header("hmac", PaymentProviderOxapay.hmac(body_raw))
        |> post(~p"/api/payment/oxapay", body_raw)

      assert json_response(conn, 200) == "OK"
    end

    test "failure due to invalid format", %{conn: conn, payment_request: payment_request} do
      body = %{
        "trackId" => payment_request.ref
      }

      body_raw = Jason.encode!(body)

      conn =
        conn
        |> put_req_header("hmac", PaymentProviderOxapay.hmac(body_raw))
        |> post(~p"/api/payment/oxapay", body_raw)

      assert json_response(conn, 400) == "NOK"
    end
  end
end
