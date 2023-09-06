defmodule Omc.ServersAccsTest do
  use Omc.DataCase, async: false
  alias Omc.Servers.ServerOps
  alias Omc.Servers
  import Omc.ServersFixtures
  import Omc.AccountsFixtures

  defp create_server_acc(_) do
    user = user_fixture()
    server = server_fixture(%{user_id: user.id})
    server_acc = server_acc_fixture(%{server_id: server.id})
    %{user: user, server: server, server_acc: server_acc}
  end

  setup [:create_server_acc]

  test "Servers.sync_server_accs_status/1 test", %{server: server, server_acc: server_acc} do
    # initial status
    assert server_acc.status == :active_pending

    # :active_pending & not File.exists -> no change
    acc_file_path(server_acc) |> File.rm()
    Servers.sync_server_accs_status(server)
    assert Servers.get_server_acc!(server_acc.id).status == :active_pending
    assert Servers.get_server_acc!(server_acc.id).lock_version == server_acc.lock_version

    # :active_pending &  File.exists -> :active
    acc_file_path(server_acc) |> File.touch()
    Servers.sync_server_accs_status(server)
    assert Servers.get_server_acc!(server_acc.id).status == :active

    # :deactive_pending &  File.exists -> :deactive_pending
    Servers.deactivate_acc(Servers.get_server_acc!(server_acc.id))
    Servers.sync_server_accs_status(server)
    assert Servers.get_server_acc!(server_acc.id).status == :deactive_pending

    # :deactive_pending &  not File.exists -> :deactive
    acc_file_path(server_acc) |> File.rm()
    Servers.sync_server_accs_status(server)
    assert Servers.get_server_acc!(server_acc.id).status == :deactive
  end

  defp acc_file_path(server_acc) do
    file_path = ServerOps.acc_file_path(server_acc)
    # this path should be created during pull from server
    Path.dirname(file_path) |> File.mkdir_p()
    file_path
  end
end
