defmodule OmcWeb.ServerAccLiveTest do
  use OmcWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Omc.ServersFixtures
  import Omc.AccountsFixtures

  setup %{} do
    user = user_fixture()
    server = server_fixture(%{user_id: user.id})
    server_acc = server_acc_fixture(%{server_id: server.id})
    %{user: user, server: server, server_acc: server_acc}
  end

  describe "Index" do
    test "lists all server_accs",
         %{conn: conn, user: user} do
      {:ok, _index_live, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/server_accs")

      assert html =~ "Listing Server accs"
    end

    test "saves new server_acc",
         %{conn: conn, user: user, server: server, server_acc: _server_acc} do
      {:ok, index_live, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/server_accs")

      assert index_live |> new_acc_click() =~ "New Server Account"

      assert_patch(index_live, ~p"/server_accs/new")

      assert index_live
             |> form("#server_acc-form",
               server_acc: %{} |> Map.put(:server_id, server.id)
             )
             |> render_submit(%{server_id: server.id})

      assert_patch(index_live, ~p"/server_accs")

      html = render(index_live)
      assert html =~ "Server acc created successfully"
    end

    test "deletes server_acc in listing",
         %{conn: conn, user: user, server: server, server_acc: server_acc} do
      {:ok, index_live, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/server_accs")

      index_live |> select_server_change(server.id)
      assert index_live |> element("#server_accs-#{server_acc.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#server_accs-#{server_acc.id}")
    end
  end

  describe "Show" do
    test "displays server_acc",
         %{conn: conn, user: user, server_acc: server_acc} do
      {:ok, _show_live, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/server_accs/#{server_acc}")

      assert html =~ "Show Server acc"
    end
  end

  defp new_acc_click(index_live) do
    index_live
    |> element(~s{a[href="/server_accs/new"]})
    |> render_click()
  end

  defp select_server_change(index_live, server_id) do
    index_live
    |> form("#filter_form", filter: %{server_id: server_id})
    |> render_change()
  end
end
