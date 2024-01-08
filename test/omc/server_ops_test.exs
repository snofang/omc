defmodule Omc.ServerOpsTest do
  use Omc.DataCase, async: true
  alias Omc.Servers.{Server, ServerOps}
  # TODO: to add test cases for ansible commands
  describe "ansible_upsert_host_file/1" do
    test "insert" do
      server = %Server{id: 1, name: "example.com", address: "1.2.3.4"}

      # cleaning up 
      File.rm_rf(Omc.Common.Utils.data_dir())
      refute file_content(server)

      # the operation
      ServerOps.ansible_upsert_host_file(server)

      # reading file content
      content = file_content(server)

      # ovpn_name and address
      assert content =~ ~r/^\s*ansible_host:\s+\"1.2.3.4\"$/m
      assert content =~ ~r/^\s*ovpn_name:\s+\"example.com\"$/m

      # password should have been replaced
      refute content |> password() |> String.starts_with?("<%=")

      assert File.exists?(ovpn_data_local_dir(content))
      assert ovpn_data_local_dir(content) == Path.join(ServerOps.server_dir(server), "ovpn_data")
    end

    test "update" do
      # insert
      server = %Server{id: 1, name: "example.com", address: "1.2.3.4"}
      File.rm_rf(Omc.Common.Utils.data_dir())
      refute file_content(server)
      ServerOps.ansible_upsert_host_file(server)
      password = server |> file_content() |> password()
      dir = server |> file_content() |> ovpn_data_local_dir()

      # new server data
      server = server |> Map.put(:name, "s11.example.com") |> Map.put(:address, "2.4.6.8")
      ServerOps.ansible_upsert_host_file(server)
      content = file_content(server)

      # ovpn_name and address should have changed
      assert content =~ ~r/^\s*ansible_host:\s+\"2.4.6.8\"$/m
      assert content =~ ~r/^\s*ovpn_name:\s+\"s11.example.com\"$/m

      # password should be unchanged
      assert content |> password() == password

      # ovpn_data_local should be unchanged
      assert dir == content |> ovpn_data_local_dir()
    end
  end

  defp ovpn_data_local_dir(content) do
    [_match, dir] = Regex.run(~r/^\s*ovpn_data_local:\s+\"(.+)\"$/m, content)
    dir
  end

  defp file_content(server) do
    case server
         |> ServerOps.ansible_host_file_path()
         |> File.read() do
      {:ok, content} -> content
      {:error, _} -> nil
    end
  end

  defp password(content) do
    [_match, pwd] = Regex.run(~r/^\s*ovpn_ca_pass:\s+\"(.+)\"$/m, content)
    pwd
  end
end
