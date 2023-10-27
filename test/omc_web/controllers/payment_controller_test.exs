defmodule OmcWeb.PaymentControllerTest do
  use OmcWeb.ConnCase, async: true
  alias Omc.Payments.PaymentProviderWp
  alias Omc.PaymentProviderWpMock
  import Omc.PaymentFixtures
  import Mox

  setup %{conn: conn} do
    PaymentProviderWpMock
    |> expect(:callback, fn params, body -> PaymentProviderWp.callback(params, body) end)
    |> expect(:not_found_response, fn -> PaymentProviderWp.not_found_response() end)

    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "callback for wp payment provider" do
    setup %{} do
      [payment_request: payment_request_fixture()]
    end

    test "not existing ref", %{conn: conn} do
      conn =
        get(
          conn,
          ~p"/api/payment/wp?reference=a6040c4d-a12e-4115-a91a-e8654f16c323&state=wait_for_confirm"
        )

      assert json_response(conn, 404) == %{"ok" => false, "error" => "NOT_FOUND"}
    end

    test "not proper state", %{conn: conn, payment_request: payment_request} do
      conn =
        get(
          conn,
          ~p"/api/payment/wp?reference=#{payment_request.ref}&state=some_state_unknown"
        )

      assert json_response(conn, 400) == %{"ok" => false}
    end
  end
end
