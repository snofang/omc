defmodule Omc.ServersTest do
  alias Omc.PricePlans
  use Omc.DataCase, async: true
  alias Omc.Servers
  alias Omc.Servers.Server
  import Omc.ServersFixtures

  describe "servers" do
    @invalid_attrs %{tag: nil, name: nil, price_plan_id: nil, status: nil}

    test "list_servers/0 returns all servers" do
      server = server_fixture()
      assert Servers.list_servers() == [server]
    end

    test "get_server!/1 returns the server with given id" do
      server = server_fixture()
      assert Servers.get_server!(server.id) == server
    end

    test "create_server/1 with valid data creates a server" do
      valid_attrs = server_valid_attrs()
      {:ok, server} = Servers.create_server(valid_attrs)
      server = Servers.get_server!(server.id)

      assert server.tag == valid_attrs.tag
      assert server.name == valid_attrs.name
      assert server.price_plan == valid_attrs.price_plan
      assert server.status == :active
    end

    test "create_server/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Servers.create_server(@invalid_attrs)
    end

    test "create_server/1 without price_plan_id should fail" do
      assert {:error, %{errors: [price_plan_id: _]}} =
               server_valid_attrs()
               |> Map.drop([:price_plan_id])
               |> Servers.create_server()
    end

    test "create_server/1 with invalid tag returns error changeset" do
      valid_attrs = server_valid_attrs()

      assert {:error, %{errors: [tag: _]}} =
               Servers.create_server(valid_attrs |> Map.put(:tag, nil))

      assert {:error, %{errors: [tag: _]}} =
               Servers.create_server(valid_attrs |> Map.put(:tag, "aaaa-bbbb-cccc"))

      assert {:error, %{errors: [tag: _]}} =
               Servers.create_server(valid_attrs |> Map.put(:tag, "aaa.bbb"))

      assert {:error, %{errors: [tag: _]}} =
               Servers.create_server(valid_attrs |> Map.put(:tag, "aaa_bbb"))

      assert {:error, %{errors: [tag: _]}} =
               Servers.create_server(valid_attrs |> Map.put(:tag, "-aaa-bbb"))
    end

    test "update_server/2 with valid data updates the server" do
      server = server_fixture()
      {:ok, new_price_plan} = PricePlans.create_price_plan(Money.new(1100))

      update_attrs = %{
        tag: "tag-updated123",
        name: "some.updated.name",
        price_plan_id: new_price_plan.id,
        status: :deactive
      }

      {:ok, server} = Servers.update_server(server, update_attrs)

      assert server.tag == "tag-updated123"
      assert server.name == "some.updated.name"
      assert server.price_plan_id == new_price_plan.id
      assert server.status == :deactive
    end

    test "update_server/2 with invalid data returns error changeset" do
      server = server_fixture()
      assert {:error, %Ecto.Changeset{}} = Servers.update_server(server, @invalid_attrs)
      assert server == Servers.get_server!(server.id)
    end

    test "delete_server/1 deletes the server having no acc" do
      server = server_fixture()
      assert {:ok, %Server{}} = Servers.delete_server(server)
      assert_raise Ecto.NoResultsError, fn -> Servers.get_server!(server.id) end
    end

    test "delete_server/1 fails to deletes the server having acc(s)" do
      server = server_fixture()
      server_acc_fixture(%{server_id: server.id})
      assert {:error, changeset} = Servers.delete_server(server)
      assert changeset.errors |> length() > 0
    end

    test "change_server/1 returns a server changeset" do
      server = server_fixture()
      assert %Ecto.Changeset{} = Servers.change_server(server)
    end
  end
end
