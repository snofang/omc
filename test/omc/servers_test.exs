defmodule Omc.ServersTest do
  use Omc.DataCase, async: true

  alias Omc.Servers
  alias Omc.Servers.Server
  alias Omc.Servers.ServerAcc

  import Omc.ServersFixtures
  import Omc.AccountsFixtures

  describe "servers" do
    @invalid_attrs %{description: nil, max_accs: nil, name: nil, price: nil, status: nil}
    setup %{} do
      %{user: user_fixture()}
    end

    test "list_servers/0 returns all servers", %{user: user} do
      server = server_fixture(%{user_id: user.id})
      assert Servers.list_servers() == [server]
    end

    test "get_server!/1 returns the server with given id", %{user: user} do
      server = server_fixture(%{user_id: user.id})
      assert Servers.get_server!(server.id) == server
    end

    test "create_server/1 with valid data creates a server", %{user: user} do
      valid_attrs = %{
        description: "some description",
        max_accs: 42,
        name: "some.name",
        price: "120.99",
        user_id: user.id
      }

      assert {:ok, %Server{} = server} = Servers.create_server(valid_attrs)
      assert server.description == "some description"
      assert server.max_accs == 42
      assert server.name == "some.name"
      assert server.price == "120.99"
      assert server.status == :active
    end

    test "create_server/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Servers.create_server(@invalid_attrs)
    end

    test "create_server/1 with invalid price returns error changeset", %{user: user} do
      valid_attrs = server_valid_attrs() |> Map.put(:user_id, user.id)
      assert {:error, %{errors: [price: _]}} =
               Servers.create_server(valid_attrs |> Map.put(:price, nil))

      assert {:error, %{errors: [price: _]}} =
               Servers.create_server(valid_attrs |> Map.put(:price, "a23"))

      assert {:error, %{errors: [price: _]}} =
               Servers.create_server(valid_attrs |> Map.put(:price, "123.123"))
    end

    test "update_server/2 with valid data updates the server" do
      user = user_fixture()
      server = server_fixture(%{user_id: user.id})

      update_attrs = %{
        description: "some updated description",
        max_accs: 43,
        name: "some.updated.name",
        price: "456.7",
        status: :deactive
      }

      assert {:ok, %Server{} = server} = Servers.update_server(server, update_attrs)
      assert server.description == "some updated description"
      assert server.max_accs == 43
      assert server.name == "some.updated.name"
      assert server.price == "456.7"
      assert server.status == :deactive
    end

    test "update_server/2 with invalid data returns error changeset" do
      user = user_fixture()
      server = server_fixture(%{user_id: user.id})
      assert {:error, %Ecto.Changeset{}} = Servers.update_server(server, @invalid_attrs)
      assert server == Servers.get_server!(server.id)
    end

    test "delete_server/1 deletes the server having no acc" do
      user = user_fixture()
      server = server_fixture(%{user_id: user.id})
      assert {:ok, %Server{}} = Servers.delete_server(server)
      assert_raise Ecto.NoResultsError, fn -> Servers.get_server!(server.id) end
    end

    test "delete_server/1 fails to deletes the server having acc(s)" do
      user = user_fixture()
      server = server_fixture(%{user_id: user.id})
      server_acc_fixture(%{server_id: server.id})
      assert {:error, changeset} = Servers.delete_server(server)
      assert changeset.errors |> length() > 0
    end

    test "change_server/1 returns a server changeset" do
      user = user_fixture()
      server = server_fixture(%{user_id: user.id})
      assert %Ecto.Changeset{} = Servers.change_server(server)
    end
  end

  defp create_server_acc(_) do
    user = user_fixture()
    server = server_fixture(%{user_id: user.id})
    server_acc = server_acc_fixture(%{server_id: server.id})
    %{user: user, server: server, server_acc: server_acc}
  end

  describe "server_accs" do
    setup [:create_server_acc]
    @invalid_attrs %{description: nil, name: nil, status: nil}

    test "list_server_accs/0 returns all server_accs",
         %{server: server, server_acc: server_acc} do
      assert Servers.list_server_accs(%{server_id: server.id}) == [server_acc]
    end

    test "get_server_acc!/1 returns the server_acc with given id",
         %{server_acc: server_acc} do
      assert Servers.get_server_acc!(server_acc.id) == server_acc
    end

    test "create_server_acc/1 with valid data creates a server_acc",
         %{server: server} do
      valid_attrs = %{description: "some description", name: "some-2345", server_id: server.id}

      assert {:ok, %ServerAcc{} = server_acc} = Servers.create_server_acc(valid_attrs)
      assert server_acc.description == "some description"
      assert server_acc.name == "some-2345"
      assert server_acc.server_id == server.id
    end

    test "create_server_acc/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Servers.create_server_acc(@invalid_attrs)
    end

    test "create_server_acc/1 with invalid name returns error changeset", %{server: server} do
      valid_attrs = %{description: "some description", name: "some-2345", server_id: server.id}

      assert {:error, %Ecto.Changeset{}} =
               Servers.create_server_acc(valid_attrs |> Map.put(:name, nil))

      assert {:error, %Ecto.Changeset{}} =
               Servers.create_server_acc(valid_attrs |> Map.put(:name, "having.dot"))

      assert {:error, %Ecto.Changeset{}} =
               Servers.create_server_acc(valid_attrs |> Map.put(:name, "having space"))
    end

    test "update_server_acc/2 with valid data updates the server_acc",
         %{server_acc: server_acc} do
      update_attrs = %{
        description: "some updated description",
        name: "some_updated-name",
        status: :active_pending
      }

      assert {:ok, %ServerAcc{} = server_acc} =
               Servers.update_server_acc(server_acc, update_attrs)

      assert server_acc.description == "some updated description"
      assert server_acc.name == "some_updated-name"
      assert server_acc.status == :active_pending
    end

    test "update_server_acc/2 with invalid data returns error changeset",
         %{server_acc: server_acc} do
      assert {:error, %Ecto.Changeset{}} = Servers.update_server_acc(server_acc, @invalid_attrs)
      assert server_acc == Servers.get_server_acc!(server_acc.id)
    end

    test "delete_server_acc/1 deletes the server_acc",
         %{server_acc: server_acc} do
      assert {:ok, %ServerAcc{}} = Servers.delete_server_acc(server_acc)
      assert_raise Ecto.NoResultsError, fn -> Servers.get_server_acc!(server_acc.id) end
    end

    test "delete_server_acc/1 fails when server_acc.status != :active_pending",
         %{server_acc: server_acc} do
      {:ok, server_acc} = Servers.update_server_acc(server_acc, %{status: :active})
      assert {:error, _} = Servers.delete_server_acc(server_acc)
    end

    test "change_server_acc/1 returns a server_acc changeset",
         %{server_acc: server_acc} do
      assert %Ecto.Changeset{} = Servers.change_server_acc(server_acc)
    end

    test "server_acc name should be unique within a server", %{user: user} do
      server_common_attrs = %{user_id: user.id, max_accs: 110, price: "50"}

      {:ok, server1} =
        server_common_attrs
        |> Map.merge(%{name: unique_server_name()})
        |> Omc.Servers.create_server()

      {:ok, server1_acc1} =
        Omc.Servers.create_server_acc(%{server_id: server1.id, name: unique_server_acc_name()})

      # not possible to add same named acc to the same server
      assert {:error, _} =
               Omc.Servers.create_server_acc(%{server_id: server1.id, name: server1_acc1.name})

      {:ok, server2} =
        server_common_attrs
        |> Map.merge(%{server_id: server1.id, name: unique_server_name()})
        |> Omc.Servers.create_server()

      # while it is possible to add same named acc to the different server
      assert {:ok, _} =
               Omc.Servers.create_server_acc(%{server_id: server2.id, name: server1_acc1.name})
    end

    test "server_acc name should not be editable if status != :active_pending", %{
      server_acc: server_acc
    } do
      {:ok, server_acc} = Servers.update_server_acc(server_acc, %{status: :active})

      assert {:error, _} =
               Servers.update_server_acc(server_acc, %{name: "edited-#{server_acc.name}"})
    end
  end
end
