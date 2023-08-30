defmodule Omc.ServerOpsTest do
  alias Omc.Servers.ServerOps
  alias Omc.Servers.Server
  use ExUnit.Case, async: false

  test "ansible hosts file should be created/modified on operation(s)" do
    Application.put_env(
      :omc,
      :cmd_wrapper,
      Application.get_env(:omc, :cmd_wrapper) |> Keyword.put(:impl, Omc.CmdWrapperMock)
    )

    Omc.CmdWrapperMock
    |> Mox.expect(:run, fn _cmd, _timeout, _topic, _ref -> nil end)

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

    assert Regex.match?(~r/^\s*ansible_host:\s+client$/m, host_file_content)

    password =
      Regex.scan(~r/^\s*ovpn_ca_pass:\s+\"(.+)\"$/m, host_file_content, capture: :all_but_first)
      |> hd()
      |> hd()

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
      Regex.scan(~r/^\s*ovpn_ca_pass:\s+\"(.+)\"$/m, host_file_content, capture: :all_but_first)
      |> hd()
      |> hd()

    assert unchanged_password == password
  end
end
