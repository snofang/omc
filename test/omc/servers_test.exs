defmodule Omc.ServersTest do
  alias Omc.PricePlans
  use Omc.DataCase, async: true

  alias Omc.Servers
  alias Omc.Servers.Server
  alias Omc.Servers.ServerAcc

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

  describe "server_accs" do
    setup %{} do
      server = server_fixture()
      server_acc = server_acc_fixture(%{server_id: server.id})
      %{server: server, server_acc: server_acc}
    end

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

    test "server_acc name should be unique within a server", %{server: server1} do
      # not possible to add same named acc to the same server
      {:ok, server1_acc1} =
        Omc.Servers.create_server_acc(%{server_id: server1.id, name: unique_server_acc_name()})

      assert {:error, _} =
               Omc.Servers.create_server_acc(%{server_id: server1.id, name: server1_acc1.name})

      # while it is possible to add same named acc to the different server
      server2 = server_fixture()

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
