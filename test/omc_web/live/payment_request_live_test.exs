defmodule OmcWeb.PaymentRequestLiveTest do
  use OmcWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Omc.PaymentFixtures
  import Omc.AccountsFixtures

  defp create_payment_request(_) do
    user = user_fixture()
    payment_request = payment_request_fixture()
    %{user: user, payment_request: payment_request}
  end

  describe "Index" do
    setup [:create_payment_request]

    test "lists all payment_requests", %{conn: conn, user: user} do
      {:ok, _index_live, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/payment_requests")

      assert html =~ "Listing Payment requests"
    end
  end

  describe "Show" do
    setup [:create_payment_request]

    test "displays payment_request", %{conn: conn, user: user, payment_request: payment_request} do
      {:ok, _show_live, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/payment_requests/#{payment_request}")

      assert html =~ "Show Payment request"
    end
  end
end
