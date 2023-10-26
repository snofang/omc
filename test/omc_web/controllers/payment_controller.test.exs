defmodule OmcWeb.PaymentControllerTest do
  use OmcWeb.ConnCase, async: true

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "callback" do
    test "failure path", %{conn: conn} do
      conn =
        get(
          conn,
          ~p"/api/payment/wp?reference=a6040c4d-a12e-4115-a91a-e8654f16c323&state=wait_for_confirm"
        )

      assert json_response(conn, 404) == %{"errors" => %{"detail" => "Not Found"}}
    end
  end
end
