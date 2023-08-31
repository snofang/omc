defmodule Omc.Servers.ServerOps do
  alias Omc.Servers.ServerTaskManager

  @doc """
  Gets server's data directory and create it if does not exist
  """
  def server_dir(server) do
    (path =
       Path.join(Omc.Common.Utils.data_dir(), to_string(server.id) |> String.pad_leading(4, "0")))
    |> File.mkdir_p!()

    path
  end

  # def server_ansible_host(server) do
  #   # EEx.eval_file()
  # end
  defp ansible_path() do
    Application.get_env(:omc, :ansible)
  end

  @doc """
  Returns server's ansible host file path
  """
  def ansible_host_file_path(server) do
    server_dir(server)
    |> Path.join("hosts.yml")
  end

  # Copies ansible host template file (replacing EEx template values) to `server`'s data dir
  # or replacing exsting server's name with new one in server's name
  defp ansible_create_host_file(server) do
    content =
      case not File.exists?(ansible_host_file_path(server)) do
        true ->
          ansible_path()
          |> Path.join("hosts.yml.eex")
          |> EEx.eval_file(server: server)

        _ ->
          existing_content =
            server
            |> ansible_host_file_path()
            |> File.read!()

          Regex.replace(
            ~r/^(\s*ansible_host:\s+)([^\s]+)$/m,
            existing_content,
            "\\1#{server.name}"
          )
      end

    ansible_host_file_path(server)
    |> File.write!(content)
  end

  # @doc """
  # Updates `server`'s ansible host file replacing its host's name only 
  # """
  # def ansible_update_host_file(server) do
  #   server_dir(server)
  #   |> Path.join("hosts.yml")
  #   |> File.write(content)
  # end

  def ansible_ovpn_install(server) do
    ansible_create_host_file(server)

    server
    |> ServerTaskManager.run_task(
      "ansible-playbook -i #{ansible_host_file_path(server)} #{Path.join(ansible_path(), "play-install.yml")}"
    )
  end
end
