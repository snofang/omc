defmodule Omc.Servers.ServerOps do
  alias Omc.Servers.ServerTaskManager
  alias Omc.Servers.ServerAcc
  alias Omc.Servers.Server
  alias Omc.Servers
  require Logger

  @doc """
  Gets server's data directory and create it if does not exist
  """
  def server_dir(server) do
    (path =
       Path.join(Omc.Common.Utils.data_dir(), to_string(server.id) |> String.pad_leading(4, "0")))
    |> File.mkdir_p!()

    path
  end

  @doc """
  Gets data dir of `server`; creating it if does not exist
  """
  def server_ovpn_data_dir(server) do
    (path =
       server
       |> server_dir()
       |> Path.join("ovpn_data"))
    |> File.mkdir_p!()

    path
  end

  @doc """
  Gets acc's account file path not matter if it exist or not
  """
  def acc_file_path(%ServerAcc{} = acc) do
    %Server{id: acc.server_id}
    |> server_ovpn_data_dir()
    |> Path.join("accs/")
    |> Path.join(acc.name <> ".ovpn")
  end

  def acc_file_exists?(%ServerAcc{} = acc) do
    acc
    |> acc_file_path()
    |> File.exists?()
  end

  defp ansible_path() do
    Application.get_env(:omc, :ansible)
  end

  @doc """
  Returns server's ansible hosts.yml file path
  """
  def ansible_host_file_path(server) do
    server_dir(server)
    |> Path.join("hosts.yml")
  end

  # Copies ansible host template file (replacing EEx template values) to `server`'s data dir
  # or replacing exsting server's name with new one in server's name
  defp ansible_upsert_host_file(server) do
    content =
      case File.exists?(ansible_host_file_path(server)) do
        false ->
          ansible_path()
          |> Path.join("hosts.yml.eex")
          |> EEx.eval_file(server: server |> Map.put(:ovpn_data, server_ovpn_data_dir(server)))

        _ ->
          server
          |> ansible_host_file_path()
          |> File.read!()
          |> then(fn c ->
            Regex.replace(~r/^(\s*ansible_host:\s+)"([^\s]+)"$/m, c, "\\1\"#{server.address}\"")
          end)
          |> then(fn c ->
            Regex.replace(~r/^(\s*ovpn_name:\s+)"([^\s]+)"$/m, c, "\\1\"#{server.name}\"")
          end)
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

  def ansible_ovpn_install(server, config_push \\ false) do
    ansible_upsert_host_file(server)

    server.id
    |> ServerTaskManager.run_task(
      "ansible-playbook" <>
        " -i #{ansible_host_file_path(server)}" <>
        " #{Path.join(ansible_path(), "play-install.yml")}" <>
        " -e '{\"ovpn_config_push\": #{config_push}}'"
    )
  end

  def ansible_ovpn_accs_update(server) do
    # it's always needed to update host file before operations
    ansible_upsert_host_file(server)

    accs_create =
      Servers.list_server_accs(%{server_id: server.id, status: :active_pending})
      |> Enum.map(fn acc -> acc.name end)

    accs_revoke =
      Servers.list_server_accs(%{server_id: server.id, status: :deactive_pending})
      |> Enum.map(fn acc -> acc.name end)

    server.id
    |> ServerTaskManager.run_task(
      "ansible-playbook" <>
        " -i #{ansible_host_file_path(server)}" <>
        " #{Path.join(ansible_path(), "play-um.yml")}" <>
        " -e '{\"clients_revoke\": " <>
        inspect(accs_revoke) <>
        ", \"clients_create\": " <>
        inspect(accs_create) <>
        "}'"
    )
  end

  @doc """
  Gets status change based on current status and existance of acc file on 
  disk (actually real availability of the acc)
  """
  @spec acc_file_based_status_change(ServerAcc.t()) :: map()
  def acc_file_based_status_change(%ServerAcc{} = acc) do
    case {acc.status, acc_file_path(acc) |> File.exists?()} do
      {:active_pending, true} ->
        %{status: :active}

      {:deactive_pending, false} ->
        %{status: :deactive}

      _ ->
        %{}
    end
  end

  @doc """
  Checks if the `conf` folder of server exist?
  """
  def conf_exist?(server_id)
  def conf_exist?(nil), do: false

  def conf_exist?(server_id) do
    %Server{id: server_id}
    |> server_ovpn_data_dir()
    |> Path.join("conf/")
    |> File.exists?()
  end
end
