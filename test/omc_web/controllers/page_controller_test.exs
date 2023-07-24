defmodule OmcWeb.PageControllerTest do
  use OmcWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == ~p"/users/log_in"
    # assert html_response(conn, 200) =~ "Peace of mind from prototype to production"
  end
end
