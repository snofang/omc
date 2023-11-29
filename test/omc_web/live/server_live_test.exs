defmodule OmcWeb.ServerLiveTest do
  use OmcWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Omc.ServersFixtures
  import Omc.AccountsFixtures

  @create_attrs %{
    tag: "src-dest",
    name: "some.name",
    price: "120.5"
  }
  @update_attrs %{
    tag: "src-dest2",
    name: "some.updated.name",
    price: "456.7",
    status: :deactive
  }
  @invalid_attrs %{tag: nil, name: nil, price: nil}

  defp create_server(_) do
    user = user_fixture()
    server = server_fixture(%{user_id: user.id})
    %{user: user, server: server}
  end

  describe "Index" do
    setup [:create_server]

    test "lists all servers",
         %{conn: conn, user: user, server: server} do
      {:ok, _index_live, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/servers")

      assert html =~ "Listing Servers"
      assert html =~ server.tag
    end

    test "saves new server", %{conn: conn, user: user} do
      {:ok, index_live, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/servers")

      assert index_live |> element("a", "New Server") |> render_click() =~
               "New Server"

      assert_patch(index_live, ~p"/servers/new")

      assert index_live
             |> form("#server-form", server: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#server-form", server: @create_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/servers")

      html = render(index_live)
      assert html =~ "Server created successfully"
      assert html =~ "src-dest"
    end

    test "updates server in listing",
         %{conn: conn, user: user, server: server} do
      {:ok, index_live, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/servers")

      assert index_live |> element("#servers-#{server.id} a", "Edit") |> render_click() =~
               "Edit Server"

      assert_patch(index_live, ~p"/servers/#{server}/edit")

      assert index_live
             |> form("#server-form", server: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#server-form", server: @update_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/servers")

      html = render(index_live)
      assert html =~ "Server updated successfully"
      assert html =~ "src-dest2"
    end

    test "deletes server in listing",
         %{conn: conn, user: user, server: server} do
      {:ok, index_live, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/servers")

      assert index_live |> element("#servers-#{server.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#servers-#{server.id}")
    end
  end

  describe "Show" do
    setup [:create_server]

    test "displays server",
         %{conn: conn, user: user, server: server} do
      {:ok, _show_live, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/servers/#{server}")

      assert html =~ "Show Server"
      assert html =~ server.tag
    end

    test "updates server within modal",
         %{conn: conn, user: user, server: server} do
      {:ok, show_live, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/servers/#{server}")

      assert show_live |> element("a", "Edit") |> render_click() =~
               "Edit Server"

      assert_patch(show_live, ~p"/servers/#{server}/show/edit")

      assert show_live
             |> form("#server-form", server: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert show_live
             |> form("#server-form", server: @update_attrs)
             |> render_submit()

      assert_patch(show_live, ~p"/servers/#{server}")

      html = render(show_live)
      assert html =~ "Server updated successfully"
      assert html =~ "src-dest2"
    end
  end
end
