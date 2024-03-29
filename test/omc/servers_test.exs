defmodule Omc.ServersTest do
  alias Omc.Usages
  alias Omc.UsagesFixtures
  alias Omc.Servers.ServerOps
  alias Omc.PricePlans
  use Omc.DataCase, async: true
  alias Omc.Servers
  alias Omc.Servers.Server
  import Omc.ServersFixtures

  describe "create_server/1" do
    @invalid_attrs %{
      tag: nil,
      addaress: nil,
      name: nil,
      price_plan_id: nil,
      status: nil,
      max_acc_count: nil
    }

    test "create_server/1 with valid data creates a server" do
      valid_attrs = server_valid_attrs()
      {:ok, server} = Servers.create_server(valid_attrs)
      server = Servers.get_server!(server.id)

      assert server.tag == valid_attrs.tag
      assert server.name == valid_attrs.name
      assert server.price_plan == valid_attrs.price_plan
      assert server.status == :active
      assert server.max_acc_count == valid_attrs.max_acc_count
    end

    test ":name validation" do
      assert {:error, %{errors: [name: {"can't be blank", [validation: :required]}]}} =
               Servers.create_server(server_valid_attrs() |> Map.put(:name, nil))

      assert {:error, %{errors: [name: {"has invalid format", [validation: :format]}]}} =
               Servers.create_server(server_valid_attrs() |> Map.put(:name, ".name"))

      assert {:error, %{errors: [name: {"has invalid format", [validation: :format]}]}} =
               Servers.create_server(server_valid_attrs() |> Map.put(:name, "name."))

      assert {:error, %{errors: [name: {"has invalid format", [validation: :format]}]}} =
               Servers.create_server(server_valid_attrs() |> Map.put(:name, "-example"))

      assert {:error, %{errors: [name: {"has invalid format", [validation: :format]}]}} =
               Servers.create_server(server_valid_attrs() |> Map.put(:name, "example-"))

      # it can also be an IP address.
      assert {:ok, _} =
               Servers.create_server(
                 server_valid_attrs()
                 |> Map.put(:name, unique_server_address())
               )
    end

    test ":address validation; the same as :name" do
      assert {:error, %{errors: [address: {"can't be blank", [validation: :required]}]}} =
               Servers.create_server(server_valid_attrs() |> Map.put(:address, nil))

      assert {:error, %{errors: [address: {"has invalid format", [validation: :format]}]}} =
               Servers.create_server(server_valid_attrs() |> Map.put(:address, "22.22.134"))

      # it can also be a domain 
      assert {:ok, _} =
               Servers.create_server(
                 server_valid_attrs()
                 |> Map.put(:address, unique_server_name())
               )
    end

    test "without price_plan_id" do
      assert {:error, %{errors: [price_plan_id: _]}} =
               server_valid_attrs()
               |> Map.drop([:price_plan_id])
               |> Servers.create_server()
    end

    test "max_acc_count zero, nil, invalid format" do
      assert {:error, %{errors: [max_acc_count: {"can't be blank", [validation: :required]}]}} =
               Servers.create_server(server_valid_attrs() |> Map.put(:max_acc_count, nil))

      assert {:error, %{errors: [max_acc_count: _]}} =
               Servers.create_server(server_valid_attrs() |> Map.put(:max_acc_count, 0))

      assert {:error, %{errors: [max_acc_count: _]}} =
               Servers.create_server(server_valid_attrs() |> Map.put(:max_acc_count, 4093))

      assert {:error, %{errors: [max_acc_count: _]}} =
               Servers.create_server(server_valid_attrs() |> Map.put(:max_acc_count, "a1234"))
    end

    test "server name should be unique" do
      assert {:ok, %{name: server_name}} = Servers.create_server(server_valid_attrs())

      assert {:error, %{errors: [name: {"has already been taken", _}]}} =
               Servers.create_server(server_valid_attrs() |> Map.put(:name, server_name))
    end

    test "max acc count" do
    end
  end

  describe "update_server/2" do
    test "valid attrs" do
      server =
        server_fixture(%{
          tag: "from1-to1",
          name: "example2.com",
          address: "1.1.1.1",
          max_acc_count: 100
        })

      {:ok, new_price_plan} =
        PricePlans.create_price_plan([Money.new(1100), Money.new(1000, :EUR)])

      {:ok, server} =
        Servers.update_server(server, %{
          tag: "from2-to2",
          name: "example2.com",
          address: "2.2.2.2",
          price_plan_id: new_price_plan.id,
          status: :deactive,
          max_acc_count: 200
        })

      assert server.tag == "from2-to2"
      assert server.name == "example2.com"
      assert server.address == "2.2.2.2"
      assert server.price_plan_id == new_price_plan.id
      assert server.status == :deactive
      assert server.max_acc_count == 200
    end

    test "invalid attrs" do
      server = server_fixture()
      assert {:error, %Ecto.Changeset{}} = Servers.update_server(server, @invalid_attrs)
      assert server == Servers.get_server!(server.id)
    end

    test "when server's conf data exists, `name` should be immutable" do
      server = server_fixture()

      # creating conf dir
      ServerOps.server_ovpn_data_dir(server)
      |> Path.join("/conf")
      |> File.mkdir_p!()

      assert {:error, %{errors: [name: {"after server config, name should not be changed.", []}]}} =
               Servers.update_server(server, %{name: "new-example.com"})
    end
  end

  describe "delete_server/1" do
    test "with no account" do
      server = server_fixture()
      assert {:ok, %Server{}} = Servers.delete_server(server)
      assert_raise Ecto.NoResultsError, fn -> Servers.get_server!(server.id) end
    end

    test "having accounts" do
      server = server_fixture()
      server_acc_fixture(%{server_id: server.id})
      assert {:error, _changeset} = Servers.delete_server(server)
    end
  end

  describe "list_servers/0" do
    setup %{} do
      %{server: server_fixture()}
    end

    test "single initial server", %{server: server} do
      [listed_server] = Servers.list_servers()

      assert server.id == listed_server.id
      assert server.name == listed_server.name
      assert server.status == listed_server.status
      assert server.max_acc_count == listed_server.max_acc_count
      assert listed_server.available_acc_count == nil
      assert listed_server.in_use_acc_count == nil
      assert server.tag == listed_server.tag
    end

    test "single server with accounts", %{server: server} do
      acc1 = server_acc_fixture(%{server_id: server.id})
      acc2 = server_acc_fixture(%{server_id: server.id})
      assert [%{available_acc_count: nil, in_use_acc_count: nil}] = Servers.list_servers()
      activate_server_acc(server, acc1)
      assert [%{available_acc_count: 1, in_use_acc_count: nil}] = Servers.list_servers()
      activate_server_acc(server, acc2)
      assert [%{available_acc_count: 2, in_use_acc_count: nil}] = Servers.list_servers()

      # making use of first available acc
      ledger = UsagesFixtures.ledger_fixture(Money.new(1000))

      Usages.start_usage(ledger)
      assert [%{available_acc_count: 1, in_use_acc_count: 1}] = Servers.list_servers()

      Usages.start_usage(ledger)
      assert [%{available_acc_count: nil, in_use_acc_count: 2}] = Servers.list_servers()
    end

    test "multiple servers with accounts", %{server: server1} do
      # setting up server2 having 2 accounts and one of them being used
      server2 = server_fixture()
      acc1 = server_acc_fixture(%{server_id: server2.id})
      activate_server_acc(server2, acc1)
      acc2 = server_acc_fixture(%{server_id: server2.id})
      activate_server_acc(server2, acc2)
      # making use of first available acc
      ledger = UsagesFixtures.ledger_fixture(Money.new(1000))
      Usages.start_usage(ledger)

      assert [%{available_acc_count: nil, in_use_acc_count: nil}] =
               Servers.list_servers(id: server1.id)

      assert [%{available_acc_count: 1, in_use_acc_count: 1}] =
               Servers.list_servers(id: server2.id)
    end
  end

  describe "servers" do
    test "get_server!/1 returns the server with given id" do
      server = server_fixture()
      assert Servers.get_server!(server.id) == server
    end

    test "change_server/1 returns a server changeset" do
      server = server_fixture()
      assert %Ecto.Changeset{} = Servers.change_server(server)
    end
  end
end
