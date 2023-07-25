defmodule Omc.ServersTest do
  use Omc.DataCase

  alias Omc.Servers

  describe "servers" do
    alias Omc.Servers.Server

    import Omc.ServersFixtures

    @invalid_attrs %{description: nil, max_accs: nil, name: nil, price: nil, status: nil}

    test "list_servers/0 returns all servers" do
      server = server_fixture()
      assert Servers.list_servers() == [server]
    end

    test "get_server!/1 returns the server with given id" do
      server = server_fixture()
      assert Servers.get_server!(server.id) == server
    end

    test "create_server/1 with valid data creates a server" do
      valid_attrs = %{
        description: "some description",
        max_accs: 42,
        name: "some name",
        price: "120.5",
        status: :active
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
      server = server_fixture()

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
      server = server_fixture()
      assert {:error, %Ecto.Changeset{}} = Servers.update_server(server, @invalid_attrs)
      assert server == Servers.get_server!(server.id)
    end

    test "delete_server/1 deletes the server" do
      server = server_fixture()
      assert {:ok, %Server{}} = Servers.delete_server(server)
      assert_raise Ecto.NoResultsError, fn -> Servers.get_server!(server.id) end
    end

    test "change_server/1 returns a server changeset" do
      server = server_fixture()
      assert %Ecto.Changeset{} = Servers.change_server(server)
    end
  end
end
