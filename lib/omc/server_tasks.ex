defmodule Omc.ServerTasks do
  @moduledoc """
  Includes all functions which should have to run serially on a given server and mostly involves Ops.
  """
  alias Omc.Servers
  alias Omc.Servers.{ServerOps, ServerTaskManager}

  @doc """
  Do queue in sequence the followings to run:
    - Servers.create_accs_up_to_max_count/1
    - fn -> ServerOps.ansible_ovpn_accs_update_command/1
    - Servers.sync_server_accs_status/1
  """
  def sync_server_accs(server) do
    ServerTaskManager.run_task(server.id, {Servers, :create_accs_up_to_max_count, [server.id]})

    ServerTaskManager.run_task_by_command_provider(
      server.id,
      fn -> ServerOps.ansible_ovpn_accs_update_command(server) end
    )

    ServerTaskManager.run_task(server.id, {Servers, :sync_server_accs_status, [server.id]})
    :ok
  end
end
