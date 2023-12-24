defmodule Omc.ServersAccsTest do
  alias Omc.Users
  alias Omc.ServerAccUsers
  alias Omc.Usages
  alias Omc.UsagesFixtures
  use Omc.DataCase, async: true
  alias Omc.Servers
  alias Omc.Servers.ServerAcc
  import Omc.ServersFixtures

  setup %{} do
    server = server_fixture()
    %{server: server}
  end

  describe "create_server_acc/1" do
    test "success case", %{server: server} do
      {:ok, %ServerAcc{} = sa} =
        %{name: "some-2345", server_id: server.id}
        |> Servers.create_server_acc()

      assert sa.name == "some-2345"
      assert sa.server_id == server.id
      assert sa.status == :active_pending
    end

    test "fail case: invalid names", %{server: server} do
      valid_attrs = %{description: "some description", name: "some-2345", server_id: server.id}

      assert {:error, %Ecto.Changeset{}} =
               Servers.create_server_acc(valid_attrs |> Map.put(:name, nil))

      assert {:error, %Ecto.Changeset{}} =
               Servers.create_server_acc(valid_attrs |> Map.put(:name, "having.dot"))

      assert {:error, %Ecto.Changeset{}} =
               Servers.create_server_acc(valid_attrs |> Map.put(:name, "having space"))
    end

    test "name should be unique within a server", %{server: server1} do
      # not possible to add same named acc to the same server
      {:ok, server1_acc1} =
        Omc.Servers.create_server_acc(%{server_id: server1.id, name: unique_server_acc_name()})

      assert {:error, %{errors: [name: _]}} =
               Omc.Servers.create_server_acc(%{server_id: server1.id, name: server1_acc1.name})

      # while it is possible to add same named acc to the different server
      server2 = server_fixture()

      assert {:ok, _} =
               Omc.Servers.create_server_acc(%{server_id: server2.id, name: server1_acc1.name})
    end
  end

  describe "Servers.sync_server_accs_status/1" do
    setup %{server: server} do
      server_acc = server_acc_fixture(%{server_id: server.id})
      %{server_acc: server_acc}
    end

    test ":active_pending & not File.exists -> no change", %{
      server: server,
      server_acc: server_acc
    } do
      acc_file_path(server_acc) |> File.rm()
      Servers.sync_server_accs_status(server.id)
      assert Servers.get_server_acc!(server_acc.id).status == :active_pending
      assert Servers.get_server_acc!(server_acc.id).lock_version == server_acc.lock_version
    end

    test ":active_pending &  File.exists -> :active", %{
      server: server,
      server_acc: server_acc
    } do
      acc_file_path(server_acc) |> File.touch()
      Servers.sync_server_accs_status(server.id)
      assert Servers.get_server_acc!(server_acc.id).status == :active
    end

    test ":deactive_pending &  File.exists -> :deactive_pending", %{
      server: server,
      server_acc: server_acc
    } do
      {:ok, server_acc} =
        server_acc |> Ecto.Changeset.change(status: :deactive_pending) |> Omc.Repo.update()

      acc_file_path(server_acc) |> File.touch()
      Servers.sync_server_accs_status(server.id)
      assert Servers.get_server_acc!(server_acc.id).status == :deactive_pending
    end

    test ":deactive_pending &  not File.exists -> :deactive", %{
      server: server,
      server_acc: server_acc
    } do
      {:ok, server_acc} =
        server_acc |> Ecto.Changeset.change(status: :deactive_pending) |> Omc.Repo.update()

      acc_file_path(server_acc) |> File.rm()
      Servers.sync_server_accs_status(server.id)
      assert Servers.get_server_acc!(server_acc.id).status == :deactive
    end

    test "if active usage exists, it should be ended" do
      # fixing a usage
      server = server_fixture(%{tag: "sync-server"})
      server_acc = server_acc_fixture(%{server_id: server.id})
      {:ok, server_acc} = Servers.update_server_acc(server_acc, %{status: :active})
      ledger = UsagesFixtures.ledger_fixture(Money.new(100_00))
      Usages.start_usage(ledger, server_tag: "sync-server")

      # there should exist a usage 
      assert ServerAccUsers.get_server_acc_user_in_use(server_acc.id)
             |> then(& &1.id)
             |> Usages.get_active_usage_by_sau_id()

      # effectively deactivating acc
      {:ok, server_acc} = Servers.update_server_acc(server_acc, %{status: :deactive_pending})
      Servers.sync_server_accs_status(server.id)

      # there should not exist an active usage anymore
      refute ServerAccUsers.get_server_acc_user_in_use(server_acc.id)
    end
  end

  describe "Servers.deactivate_acc/1" do
    setup %{server: server} do
      server_acc = server_acc_fixture(%{server_id: server.id})
      %{server_acc: server_acc}
    end

    test "success case; server_acc.status = :active status", %{server_acc: server_acc} do
      {:ok, server_acc} =
        server_acc |> Ecto.Changeset.change(status: :active) |> Omc.Repo.update()

      assert {:ok, %{status: :deactive_pending}} = Servers.deactivate_acc(server_acc)
    end

    test "success case; server_acc.status = :deactive_pending", %{server_acc: server_acc} do
      {:ok, server_acc} =
        server_acc |> Ecto.Changeset.change(status: :deactive_pending) |> Omc.Repo.update()

      assert {:ok, %{status: :deactive_pending}} = Servers.deactivate_acc(server_acc)
    end

    test "fail case; server_acc.status in (:deactive, :active_pending)", %{server_acc: server_acc} do
      # :active_pending
      assert {:error, %{errors: [status: _]}} = Servers.deactivate_acc(server_acc)

      # :deactive
      {:ok, server_acc} =
        server_acc |> Ecto.Changeset.change(status: :deactive) |> Omc.Repo.update()

      assert {:error, %{errors: [status: _]}} = Servers.deactivate_acc(server_acc)
    end
  end

  describe "Servers.update_server_acc/2" do
    setup %{server: server} do
      server_acc = server_acc_fixture(%{server_id: server.id})
      %{server_acc: server_acc}
    end

    test "success case", %{server_acc: server_acc} do
      assert {:ok,
              %ServerAcc{
                name: "some_updated-name",
                status: :active_pending
              }} =
               Servers.update_server_acc(server_acc, %{
                 name: "some_updated-name"
               })
    end

    test "fail case; invalid name", %{server_acc: server_acc} do
      assert {:error, %{errors: [name: _]}} =
               Servers.update_server_acc(server_acc, %{name: "new name with space"})
    end

    test "fail case; status != :active_pending", %{server_acc: server_acc} do
      # :active
      {:ok, server_acc} = Servers.update_server_acc(server_acc, %{status: :active})

      assert {:error, %{errors: [name: _]}} =
               Servers.update_server_acc(server_acc, %{name: "some_edited_name"})

      # :deactive_pending
      {:ok, server_acc} = Servers.update_server_acc(server_acc, %{status: :deactive_pending})

      assert {:error, %{errors: [name: _]}} =
               Servers.update_server_acc(server_acc, %{name: "some_edited_name"})

      # :deactive
      {:ok, server_acc} = Servers.update_server_acc(server_acc, %{status: :deactive})

      assert {:error, %{errors: [name: _]}} =
               Servers.update_server_acc(server_acc, %{name: "some_edited_name"})
    end
  end

  describe "Servers.delete_server_acc/1" do
    setup %{server: server} do
      server_acc = server_acc_fixture(%{server_id: server.id})
      %{server_acc: server_acc}
    end

    test "success case; status == :active_pending", %{server_acc: server_acc} do
      assert {:ok, %ServerAcc{}} = Servers.delete_server_acc(server_acc)
      assert_raise Ecto.NoResultsError, fn -> Servers.get_server_acc!(server_acc.id) end
    end

    test "fail case; status != :active_pending",
         %{server_acc: server_acc} do
      # :active
      {:ok, server_acc} = Servers.update_server_acc(server_acc, %{status: :active})
      assert {:error, %{errors: [status: _]}} = Servers.delete_server_acc(server_acc)

      # :deactive_pending
      {:ok, server_acc} = Servers.update_server_acc(server_acc, %{status: :deactive_pending})
      assert {:error, %{errors: [status: _]}} = Servers.delete_server_acc(server_acc)

      # :deactive
      {:ok, server_acc} = Servers.update_server_acc(server_acc, %{status: :deactive})
      assert {:error, %{errors: [status: _]}} = Servers.delete_server_acc(server_acc)
    end
  end

  describe "Servers.list_server_accs/3" do
    setup %{server: server} do
      sa1 = server_acc_fixture(%{server_id: server.id, name: "name_of_sa1"})

      {:ok, sa2} =
        server_acc_fixture(%{server_id: server.id, name: "sa2_name"})
        |> Servers.update_server_acc(%{status: :active})

      sa3 =
        server_acc_fixture(%{server_id: server.id, name: "great_sa3_name"})
        |> Servers.update_server_acc(%{status: :active})
        |> then(fn {:ok, sa} -> Servers.update_server_acc(sa, %{status: :deactive_pending}) end)

      server1 = server_fixture()
      sa4 = server_acc_fixture(%{server_id: server1.id, name: "server1_sa4"})

      %{sa1: sa1, sa2: sa2, sa3: sa3, sa4: sa4}
    end

    test "without filter, returns all" do
      assert Servers.list_server_accs() |> length() == 4
    end

    test "paging" do
      assert Servers.list_server_accs(%{}, 1, 2) |> length() == 2
      assert Servers.list_server_accs(%{}, 2, 2) |> length() == 2
      assert Servers.list_server_accs(%{}, 3, 2) |> length() == 0
    end

    test "by server", %{server: server} do
      assert Servers.list_server_accs(%{server_id: server.id}) |> length() == 3
    end

    test "by server & name", %{server: server} do
      assert Servers.list_server_accs(%{server_id: server.id, name: "sa1"}) |> length() == 1
      assert Servers.list_server_accs(%{server_id: server.id, name: "sa"}) |> length() == 3
    end

    test "by server & status", %{server: server} do
      assert Servers.list_server_accs(%{server_id: server.id, status: :active_pending})
             |> length() == 1

      assert Servers.list_server_accs(%{server_id: server.id, status: :active})
             |> length() == 1

      assert Servers.list_server_accs(%{server_id: server.id, status: :deactive_pending})
             |> length() == 1
    end

    test "by user_info", %{server: server} do
      # setting up a new acc having usage
      ledger = UsagesFixtures.ledger_fixture(Money.new(3000))

      Users.upsert_user_info(%{
        user_type: ledger.user_type,
        user_id: ledger.user_id,
        user_name: "user_Jim1_name",
        first_name: "first_Jim2_name",
        last_name: "last_Jim3_name"
      })

      _usage = UsagesFixtures.usage_fixture(%{server: server, user_attrs: ledger})
      user_info_text = "un:user_Jim1_name, fn:first_Jim2_name, ln:last_Jim3_name"
      assert [%{user_info: ^user_info_text}] = Servers.list_server_accs(%{user_info: "Jim1"})
      assert [%{user_info: ^user_info_text}] = Servers.list_server_accs(%{user_info: "Jim2"})
      assert [%{user_info: ^user_info_text}] = Servers.list_server_accs(%{user_info: "Jim3"})
    end
  end

  describe "Servers.change_server_acc/1" do
    test "default changeset; no change" do
      assert %Ecto.Changeset{errors: [], changes: %{}, valid?: true} =
               Servers.change_server_acc(%ServerAcc{
                 name: "name",
                 status: :active_pending,
                 server_id: 1
               })
    end

    test "invalid change; :active_pending -> !:active" do
      assert %Ecto.Changeset{errors: [status: _], valid?: false} =
               Servers.change_server_acc(
                 %ServerAcc{
                   name: "name",
                   status: :active_pending,
                   server_id: 1
                 },
                 %{status: :deactive_pending}
               )

      assert %Ecto.Changeset{errors: [status: _], valid?: false} =
               Servers.change_server_acc(
                 %ServerAcc{
                   name: "name",
                   status: :active_pending,
                   server_id: 1
                 },
                 %{status: :deactive}
               )
    end

    test "invalid change; :active -> !:deactive_pending" do
      assert %Ecto.Changeset{errors: [status: _], valid?: false} =
               Servers.change_server_acc(
                 %ServerAcc{
                   name: "name",
                   status: :active,
                   server_id: 1
                 },
                 %{status: :active_pending}
               )

      assert %Ecto.Changeset{errors: [status: _], valid?: false} =
               Servers.change_server_acc(
                 %ServerAcc{
                   name: "name",
                   status: :active,
                   server_id: 1
                 },
                 %{status: :deactive}
               )
    end

    test "invalid change; :deactive_pending -> !:deactive" do
      assert %Ecto.Changeset{errors: [status: _], valid?: false} =
               Servers.change_server_acc(
                 %ServerAcc{
                   name: "name",
                   status: :deactive_pending,
                   server_id: 1
                 },
                 %{status: :active}
               )

      assert %Ecto.Changeset{errors: [status: _], valid?: false} =
               Servers.change_server_acc(
                 %ServerAcc{
                   name: "name",
                   status: :deactive_pending,
                   server_id: 1
                 },
                 %{status: :active_pending}
               )
    end

    test "invalid change; :deactive -> !:deactive" do
      assert %Ecto.Changeset{errors: [status: _], valid?: false} =
               Servers.change_server_acc(
                 %ServerAcc{
                   name: "name",
                   status: :deactive,
                   server_id: 1
                 },
                 %{status: :active_pending}
               )

      assert %Ecto.Changeset{errors: [status: _], valid?: false} =
               Servers.change_server_acc(
                 %ServerAcc{
                   name: "name",
                   status: :deactive,
                   server_id: 1
                 },
                 %{status: :active}
               )

      assert %Ecto.Changeset{errors: [status: _], valid?: false} =
               Servers.change_server_acc(
                 %ServerAcc{
                   name: "name",
                   status: :deactive,
                   server_id: 1
                 },
                 %{status: :deactive_pending}
               )
    end
  end

  describe "Servers.get_server_acc!/1" do
    setup %{server: server} do
      server_acc = server_acc_fixture(%{server_id: server.id})
      %{server_acc: server_acc}
    end

    test "success case", %{server_acc: server_acc} do
      assert Servers.get_server_acc!(server_acc.id) == server_acc
    end
  end
end
