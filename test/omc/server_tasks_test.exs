defmodule Omc.ServerTasksTest do
  alias Omc.Servers.ServerOps
  # in favoure of `Omc.Servers.ServerTaskManagerTest`
  use Omc.DataCase, async: false
  alias Omc.Servers
  alias Omc.ServerTasks
  alias Omc.Servers.ServerTaskManager
  import Mox
  import Omc.ServersFixtures
  import Omc.TestUtils

  setup %{} do
    start_supervised(ServerTaskManager)
    Ecto.Adapters.SQL.Sandbox.allow(Omc.Repo, self(), Process.whereis(ServerTaskManager))
    %{server: server_fixture(%{max_acc_count: 1})}
  end

  describe "sync_server_accs/1" do
    test "create and activate acc - normal success flow", %{server: server} do
      Omc.CmdWrapperMock
      |> stub(:run, fn cmd, _timeout, _topic, _ref ->
        [_, acc_name] = Regex.run(~r/"clients_create": \["(.+)"\]/, cmd)

        acc_file_path =
          server
          |> ServerOps.server_ovpn_data_dir()
          |> Path.join("accs/")
          |> Path.join(acc_name <> ".ovpn")

        acc_file_path
        |> Path.dirname()
        |> File.mkdir_p!()

        acc_file_path
        |> File.touch!()

        {:ok, "command executed"}
      end)
      |> allow(self(), Process.whereis(ServerTaskManager))

      ServerTasks.sync_server_accs(server)
      eventual_assert(fn -> match?([%{status: :active}], Servers.list_server_accs()) end, 1000)
    end
  end
end
