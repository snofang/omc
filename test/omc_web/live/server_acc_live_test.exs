defmodule OmcWeb.ServerAccLiveTest do
  use OmcWeb.ConnCase

  import Phoenix.LiveViewTest
  import Omc.ServersFixtures
  import Omc.AccountsFixtures

  @create_attrs %{description: "some description", name: "some name", status: :active}
  @update_attrs %{
    description: "some updated description",
    name: "some updated name",
    status: :deactive
  }
  @invalid_attrs %{description: nil, name: nil, status: nil}

  defp create_server_acc(_) do
    server_acc = server_acc_fixture()
    %{server_acc: server_acc}
  end

  describe "Index" do
    setup [:create_server_acc]

    test "lists all server_accs", %{conn: conn, server_acc: server_acc} do
      {:ok, _index_live, html} = conn
        |> log_in_user(user_fixture())
        |> live(~p"/server_accs")


      assert html =~ "Listing Server accs"
      assert html =~ server_acc.description
    end

    test "saves new server_acc", %{conn: conn} do
      {:ok, index_live, _html} = conn
        |> log_in_user(user_fixture())
        |> live(~p"/server_accs")

      assert index_live |> element("a", "New Server acc") |> render_click() =~
               "New Server acc"

      assert_patch(index_live, ~p"/server_accs/new")

      assert index_live
             |> form("#server_acc-form", server_acc: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#server_acc-form", server_acc: @create_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/server_accs")

      html = render(index_live)
      assert html =~ "Server acc created successfully"
      assert html =~ "some description"
    end

    test "updates server_acc in listing", %{conn: conn, server_acc: server_acc} do
      {:ok, index_live, _html} = conn
        |> log_in_user(user_fixture())
        |> live(~p"/server_accs")

      assert index_live |> element("#server_accs-#{server_acc.id} a", "Edit") |> render_click() =~
               "Edit Server acc"

      assert_patch(index_live, ~p"/server_accs/#{server_acc}/edit")

      assert index_live
             |> form("#server_acc-form", server_acc: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#server_acc-form", server_acc: @update_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/server_accs")

      html = render(index_live)
      assert html =~ "Server acc updated successfully"
      assert html =~ "some updated description"
    end

    test "deletes server_acc in listing", %{conn: conn, server_acc: server_acc} do
      {:ok, index_live, _html} = conn
        |> log_in_user(user_fixture())
        |> live(~p"/server_accs")

      assert index_live |> element("#server_accs-#{server_acc.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#server_accs-#{server_acc.id}")
    end
  end

  describe "Show" do
    setup [:create_server_acc]

    test "displays server_acc", %{conn: conn, server_acc: server_acc} do
      {:ok, _show_live, html} = conn 
        |> log_in_user(user_fixture())
        |> live(~p"/server_accs/#{server_acc}")

      assert html =~ "Show Server acc"
      assert html =~ server_acc.description
    end

    test "updates server_acc within modal", %{conn: conn, server_acc: server_acc} do
      {:ok, show_live, _html} = conn
        |> log_in_user(user_fixture())
        |> live(~p"/server_accs/#{server_acc}")
      

      assert show_live |> element("a", "Edit") |> render_click() =~
               "Edit Server acc"

      assert_patch(show_live, ~p"/server_accs/#{server_acc}/show/edit")

      assert show_live
             |> form("#server_acc-form", server_acc: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert show_live
             |> form("#server_acc-form", server_acc: @update_attrs)
             |> render_submit()

      assert_patch(show_live, ~p"/server_accs/#{server_acc}")

      html = render(show_live)
      assert html =~ "Server acc updated successfully"
      assert html =~ "some updated description"
    end
  end
end
