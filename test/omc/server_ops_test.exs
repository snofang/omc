defmodule Omc.ServerOpsTest do
  use Omc.DataCase, async: false
  alias Omc.Servers.{ServerOps, Server, ServerTaskManager}
  import Mox

  setup %{} do
    start_supervised(ServerTaskManager)
    :ok
  end

  test "ansible hosts file should be created/modified on operation(s)" do
    Omc.CmdWrapperMock
    |> stub(:run, fn _cmd, _timeout, _topic, _ref -> {:ok, "command executed"} end)
    |> allow(self(), Process.whereis(ServerTaskManager))

    #
    # on first install operation it should be created
    #
    File.rm_rf(Omc.Common.Utils.data_dir())
    server = %Server{id: 1, name: "example.com", address: "1.2.3.4"}
    ServerOps.ansible_ovpn_install(server)

    host_file_content =
      server
      |> ServerOps.ansible_host_file_path()
      |> File.read!()

    # ovpn_name and address
    assert Regex.match?(~r/^\s*ansible_host:\s+\"1.2.3.4\"$/m, host_file_content)
    assert Regex.match?(~r/^\s*ovpn_name:\s+\"example.com\"$/m, host_file_content)

    # paaword 
    password =
      Regex.run(~r/^\s*ovpn_ca_pass:\s+\"(.+)\"$/m, host_file_content, capture: :all_but_first)
      |> hd()

    # ovpn_data_local 
    ovpn_data_local_dir =
      Regex.run(~r/^\s*ovpn_data_local:\s+\"(.+)\"$/m, host_file_content, capture: :all_but_first)
      |> hd()

    assert File.exists?(ovpn_data_local_dir)
    assert ovpn_data_local_dir == Path.join(ServerOps.server_dir(server), "ovpn_data")

    assert not (password |> String.starts_with?("<%="))

    #
    # changing server name and address should be affected
    #
    server = server |> Map.put(:name, "s11.example.com") |> Map.put(:address, "2.4.6.8")
    ServerOps.ansible_ovpn_install(server)

    host_file_content =
      server
      |> ServerOps.ansible_host_file_path()
      |> File.read!()

    assert host_file_content =~ ~r/^\s*ansible_host:\s+\"2.4.6.8\"$/m
    assert host_file_content =~ ~r/^\s*ovpn_name:\s+\"s11.example.com\"$/m

    unchanged_password =
      Regex.run(~r/^\s*ovpn_ca_pass:\s+\"(.+)\"$/m, host_file_content, capture: :all_but_first)
      |> hd()

    assert unchanged_password == password

    # ovpn_data_local 
    unchanged_ovpn_data_local_dir =
      Regex.run(~r/^\s*ovpn_data_local:\s+\"(.+)\"$/m, host_file_content, capture: :all_but_first)
      |> hd()

    assert unchanged_ovpn_data_local_dir == ovpn_data_local_dir
  end
end
