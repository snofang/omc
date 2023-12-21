defmodule OmcWeb.PaymentRequestLiveTest do
  alias Omc.PaymentProviderMock
  use OmcWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Omc.PaymentFixtures
  import Omc.AccountsFixtures
  import Mox

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

  describe "inquiry state" do
    setup [:create_payment_request]

    test "successful inquiry state", %{conn: conn, user: user, payment_request: pr} do
      PaymentProviderMock
      |> expect(:send_state_inquiry_request, fn _ ->
        {:ok, %{state: :pending, data: %{"res_key" => "res_value"}}}
      end)

      {:ok, index_live, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/payment_requests")

      assert index_live
             |> element("#payment_requests-#{pr.id} a", "Inquiry State")
             |> render_click() =~
               "Got inquiry resoponse successfully."
    end

    test "failed inquiry state", %{conn: conn, user: user, payment_request: pr} do
      PaymentProviderMock
      |> expect(:send_state_inquiry_request, fn _ ->
        {:error, %{"error" => "some_error"}}
      end)

      {:ok, index_live, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/payment_requests")

      assert index_live
             |> element("#payment_requests-#{pr.id} a", "Inquiry State")
             |> render_click() =~
               "Error status inquiry; cause: %{&quot;error&quot; =&gt; &quot;some_error&quot;}"
    end
  end
end
