defmodule Omc.ServerOpsTest do
  alias Omc.Servers.ServerOps
  alias Omc.Servers.Server
  use Omc.DataCase, async: false
  import Mox
  setup :set_mox_from_context
  setup :verify_on_exit!

  test "ansible hosts file should be created/modified on operation(s)" do
    Mox.defmock(Omc.CmdWrapperMock, for: Omc.Common.CmdWrapper)

    Application.put_env(
      :omc,
      :cmd_wrapper,
      Application.put_env(:omc, :cmd_wrapper_impl, Omc.CmdWrapperMock)
    )

    Omc.CmdWrapperMock
    |> expect(:run, 2, fn _cmd, _timeout, _topic, _ref -> {:ok, "command executed"} end)

    #
    # on first install operation it should be created
    #
    File.rm_rf!(Omc.Common.Utils.data_dir())
    server = %Server{id: 1, name: "client"}
    ServerOps.ansible_ovpn_install(server)

    host_file_content =
      server
      |> ServerOps.ansible_host_file_path()
      |> File.read!()

    # host name 
    assert Regex.match?(~r/^\s*ansible_host:\s+client$/m, host_file_content)

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
    # changing server name should be affected
    #
    server = server |> Map.put(:name, "s111.example.com")
    ServerOps.ansible_ovpn_install(server)

    host_file_content =
      server
      |> ServerOps.ansible_host_file_path()
      |> File.read!()

    assert Regex.match?(~r/^\s*ansible_host:\s+s111.example.com$/m, host_file_content)

    unchanged_password =
      Regex.run(~r/^\s*ovpn_ca_pass:\s+\"(.+)\"$/m, host_file_content, capture: :all_but_first)
      |> hd()
    assert unchanged_password == password

    # ovpn_data_local 
    unchanged_ovpn_data_local_dir =
      Regex.run(~r/^\s*ovpn_data_local:\s+\"(.+)\"$/m, host_file_content, capture: :all_but_first)
      |> hd()
    assert  unchanged_ovpn_data_local_dir == ovpn_data_local_dir
    
  end

end
