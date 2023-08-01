defmodule Omc.ServersTest do
  use Omc.DataCase

  alias Omc.Servers

  describe "servers" do
    alias Omc.Servers.Server

    import Omc.ServersFixtures
    import Omc.AccountsFixtures

    @invalid_attrs %{description: nil, max_accs: nil, name: nil, price: nil, status: nil}

    test "list_servers/0 returns all servers" do
      user = user_fixture()
      server = server_fixture(%{user_id: user.id})
      assert Servers.list_servers() == [server]
    end

    test "get_server!/1 returns the server with given id" do
      user = user_fixture()
      server = server_fixture(%{user_id: user.id})
      assert Servers.get_server!(server.id) == server
    end

    test "create_server/1 with valid data creates a server" do
      user = user_fixture()
      valid_attrs = %{
        description: "some description",
        max_accs: 42,
        name: "some name",
        price: "120.5",
        user_id: user.id
      }
      

      assert {:ok, %Server{} = server} = Servers.create_server(valid_attrs)
      assert server.description == "some description"
      assert server.max_accs == 42
      assert server.name == "some name"
      assert server.price == Decimal.new("120.5")
      assert server.status == :active
    end

    test "create_server/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Servers.create_server(@invalid_attrs)
    end

    test "update_server/2 with valid data updates the server" do
      user = user_fixture()
      server = server_fixture(%{user_id: user.id})

      update_attrs = %{
        description: "some updated description",
        max_accs: 43,
        name: "some updated name",
        price: "456.7",
        status: :deactive
      }

      assert {:ok, %Server{} = server} = Servers.update_server(server, update_attrs)
      assert server.description == "some updated description"
      assert server.max_accs == 43
      assert server.name == "some updated name"
      assert server.price == Decimal.new("456.7")
      assert server.status == :deactive
    end

    test "update_server/2 with invalid data returns error changeset" do
      user = user_fixture()
      server = server_fixture(%{user_id: user.id})
      assert {:error, %Ecto.Changeset{}} = Servers.update_server(server, @invalid_attrs)
      assert server == Servers.get_server!(server.id)
    end

    test "delete_server/1 deletes the server" do
      user = user_fixture()
      server = server_fixture(%{user_id: user.id})
      assert {:ok, %Server{}} = Servers.delete_server(server)
      assert_raise Ecto.NoResultsError, fn -> Servers.get_server!(server.id) end
    end

    test "change_server/1 returns a server changeset" do
      user = user_fixture()
      server = server_fixture(%{user_id: user.id})
      assert %Ecto.Changeset{} = Servers.change_server(server)
    end
  end

  describe "server_accs" do
    alias Omc.Servers.ServerAcc

    import Omc.ServersFixtures

    @invalid_attrs %{description: nil, name: nil, status: nil}

    test "list_server_accs/0 returns all server_accs" do
      server_acc = server_acc_fixture()
      assert Servers.list_server_accs() == [server_acc]
    end

    test "get_server_acc!/1 returns the server_acc with given id" do
      server_acc = server_acc_fixture()
      assert Servers.get_server_acc!(server_acc.id) == server_acc
    end

    test "create_server_acc/1 with valid data creates a server_acc" do
      valid_attrs = %{description: "some description", name: "some name", status: :active}

      assert {:ok, %ServerAcc{} = server_acc} = Servers.create_server_acc(valid_attrs)
      assert server_acc.description == "some description"
      assert server_acc.name == "some name"
      assert server_acc.status == :active
    end

    test "create_server_acc/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Servers.create_server_acc(@invalid_attrs)
    end

    test "update_server_acc/2 with valid data updates the server_acc" do
      server_acc = server_acc_fixture()

      update_attrs = %{
        description: "some updated description",
        name: "some updated name",
        status: :deactive
      }

      assert {:ok, %ServerAcc{} = server_acc} =
               Servers.update_server_acc(server_acc, update_attrs)

      assert server_acc.description == "some updated description"
      assert server_acc.name == "some updated name"
      assert server_acc.status == :deactive
    end

    test "update_server_acc/2 with invalid data returns error changeset" do
      server_acc = server_acc_fixture()
      assert {:error, %Ecto.Changeset{}} = Servers.update_server_acc(server_acc, @invalid_attrs)
      assert server_acc == Servers.get_server_acc!(server_acc.id)
    end

    test "delete_server_acc/1 deletes the server_acc" do
      server_acc = server_acc_fixture()
      assert {:ok, %ServerAcc{}} = Servers.delete_server_acc(server_acc)
      assert_raise Ecto.NoResultsError, fn -> Servers.get_server_acc!(server_acc.id) end
    end

    test "change_server_acc/1 returns a server_acc changeset" do
      server_acc = server_acc_fixture()
      assert %Ecto.Changeset{} = Servers.change_server_acc(server_acc)
    end
  end
end
