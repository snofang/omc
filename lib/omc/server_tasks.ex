defmodule Omc.ServerTasks do
  @moduledoc """
  Includes all functions which should have to run serially on a given server and mostly involves Ops.
  """
  use GenServer
  alias Phoenix.PubSub
  alias Omc.Servers
  alias Omc.Servers.{ServerOps, ServerTaskManager}

  @doc """
  Do queue in sequence the followings to run:
    - Servers.create_accs_up_to_max_count/1
    - ansible_upsert_host_file/1
    - fn -> ServerOps.ansible_ovpn_accs_update_command/1
    - Servers.sync_server_accs_status/1
  """
  def sync_accs_server_task(server, max_acc_count? \\ false) do
    batch_size =
      case max_acc_count? do
        true -> server.max_acc_count
        _ -> Application.get_env(:omc, __MODULE__)[:batch_size] || 1
      end

    ServerTaskManager.run_task(
      server.id,
      {Servers, :create_accs_up_to_max_count, [server.id, batch_size]}
    )

    ServerTaskManager.run_task(
      server.id,
      {ServerOps, :ansible_upsert_host_file, [server]}
    )

    ServerTaskManager.run_task_by_command_provider(
      server.id,
      fn -> ServerOps.ansible_ovpn_accs_update_command(server, batch_size) end
    )

    ServerTaskManager.run_task(
      server.id,
      {Servers, :sync_server_accs_status, [server.id, batch_size]}
    )

    :ok
  end

  def install_ovpn_server_task(server) do
    ServerTaskManager.run_task(
      server.id,
      {ServerOps, :ansible_upsert_host_file, [server]}
    )

    ServerTaskManager.run_task_by_command_provider(
      server.id,
      fn -> ServerOps.ansible_ovpn_install_command(server) end
    )
  end

  def start_link(_args) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_init_arg) do
    PubSub.subscribe(Omc.PubSub, "server-tasks")
    {:ok, nil}
  end

  def handle_info({:sync_accs_server_task, server_id}, state) do
    server_id
    |> Servers.get_server!()
    |> sync_accs_server_task()

    {:noreply, state}
  end
end
