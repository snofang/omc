defmodule Omc.Servers.ServerTaskManager do
  @moduledoc """
  To track each server's task progress(to keep output messages in memory) for showing purpose.
  """
  # TODO: to persist progress messages for each server and intepret the outcomes
  # so that it would be possible to change the state of the server accordingly
  # TODO: to prevent concurrent tasks on a single machine 
  # TODO: to parse the last line of ansible call and detect success/failure of 
  # the tasks. it is required specially in acc management
  require Logger
  alias Omc.Common.CmdWrapper
  alias Phoenix.PubSub
  use GenServer

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(_args) do
    PubSub.subscribe(Omc.PubSub, "server_task_progress")

    timeout = Application.get_env(:omc, :server_call_timeout)

    {:ok, %{timeout: timeout}}
  end

  def handle_cast({:run, server_id, cmd}, state = %{timeout: timeout}) do
    Task.Supervisor.start_child(Omc.TaskSupervisor, CmdWrapper, :run, [
      cmd,
      timeout,
      "server_task_progress",
      server_id
    ])

    {:noreply, state |> add_log(server_id, cmd)}
  end

  def handle_cast({:clear, server_id}, state) do
    {:noreply, state |> Map.put(server_id, "")}
  end

  def handle_info({:progress, server_id, message}, state) do
    Logger.info("server_task_progress, server_id: #{server_id}, message: #{message}")
    {:noreply, state |> add_log(server_id, message)}
  end

  def handle_call({:get, server_id}, _from, state) do
    {:reply, state |> Map.get(server_id), state}
  end

  def get_task_log(server_id) do
    GenServer.call(__MODULE__, {:get, server_id})
  end

  def run_task(server, cmd) do
    GenServer.cast(__MODULE__, {:run, server.id, cmd})
  end

  defp add_log(state, server_id, prompt) do
    state |> Map.update(server_id, prompt, fn value -> value <> prompt end)
  end

  def clear_task_log(server_id) do
    GenServer.cast(__MODULE__, {:clear, server_id})
  end
end
