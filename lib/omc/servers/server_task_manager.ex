defmodule Omc.Servers.ServerTaskManager do
  @moduledoc """
  To track each server's task progress(to keep output messages in memory) for showing purpose.
  """
  # TODO: to persist progress messages for each server and intepret the outcomes
  # so that it would be possible to change the state of the server accordingly
  # TODO: to parse the last line of ansible call and detect success/failure of 
  # the tasks. it is required specially in acc management
  require Logger
  alias Omc.Common.Queue
  alias Omc.Common.CmdWrapper
  alias Phoenix.PubSub
  use GenServer

  @spec run_task_by_command_provider(server_id :: integer(), fun :: (() -> binary())) :: :ok
  def run_task_by_command_provider(server_id, fun) do
    GenServer.cast(__MODULE__, {:run_cmd, server_id, {:command_provider, fun}})
  end

  def run_task(server_id, cmd) do
    GenServer.cast(__MODULE__, {:run_cmd, server_id, cmd})
  end

  def cancel_running_task(server_id) do
    GenServer.cast(__MODULE__, {:cancel_running_task, server_id})
  end

  def get_task_log(server_id) do
    GenServer.call(__MODULE__, {:get_task_log, server_id})
  end

  def clear_task_log(server_id) do
    GenServer.cast(__MODULE__, {:clear_task_log, server_id})
  end

  def get_task_list(server_id) do
    GenServer.call(__MODULE__, {:get_task_list, server_id})
  end

  @doc false
  defmodule ServerTaskState do
    defstruct task_log: "", cmd_queue: Queue.new(), running_cmd_task: nil

    def queue_cmd(s, cmd) do
      %{s | cmd_queue: s.cmd_queue |> Queue.push(cmd)}
    end

    def add_task_log(s, task_log) do
      max_length =
        Application.get_env(:omc, Omc.Servers.ServerTaskManager)[:max_log_length_per_server] ||
          1_000

      %{s | task_log: (s.task_log <> task_log) |> String.slice(-max_length, max_length)}
    end

    def clear_task_log(s) do
      %{s | task_log: ""}
    end
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    PubSub.subscribe(Omc.PubSub, "server_task_progress")

    timeout = Application.get_env(:omc, :server_call_timeout)

    {:ok, %{timeout: timeout, ref_map: %{}}}
  end

  @impl true
  def handle_call({:get_task_log, server_id}, _from, state) do
    state =
      case state[server_id] do
        nil ->
          state |> add_task_log(server_id, "")

        _ ->
          state
      end

    {:reply, state[server_id].task_log, state}
  end

  @impl true
  def handle_call({:get_task_list, server_id}, _from, state) do
    result =
      case state[server_id] do
        nil ->
          []

        %ServerTaskState{} = sts ->
          sts.cmd_queue |> Queue.to_list()
      end

    {:reply, result, state}
  end

  @impl true
  def handle_cast({:cancel_running_task, server_id}, state) do
    if state[server_id] do
      case state[server_id].running_cmd_task do
        nil ->
          {:noreply, state}

        task ->
          Task.shutdown(task, :brutal_kill)
          # run any queued command, if any
          GenServer.cast(__MODULE__, {:run_cmd, server_id})
          # removing ref from ref_map and server state
          {:noreply,
           state
           |> Map.put(server_id, %{state[server_id] | running_cmd_task: nil})
           |> Map.put(:ref_map, state.ref_map |> Map.delete(task.ref))}
      end
    end
  end

  @impl true
  def handle_cast({:run_cmd, server_id, cmd}, state) do
    {:noreply, state |> queue_cmd(server_id, cmd) |> run_server_cmd(server_id)}
  end

  @impl true
  def handle_cast({:run_cmd, server_id}, state) do
    {:noreply, state |> run_server_cmd(server_id)}
  end

  @impl true
  def handle_cast({:clear_task_log, server_id}, state) do
    {:noreply, state |> Map.put(server_id, state[server_id] |> ServerTaskState.clear_task_log())}
  end

  @impl true
  def handle_info({:progress, server_id, message}, state) do
    Logger.info("task_progress, server_id: #{server_id}, message: #{message}")
    {:noreply, state |> add_task_log(server_id, message)}
  end

  # The task ended anyway 
  @impl true
  def handle_info({:DOWN, ref, :process, _pid, reason}, %{ref_map: ref_map} = state) do
    server_id = ref_map[ref]

    # Just logging and ignoring failure
    if reason != :normal do
      Logger.error(
        ~s(Server task execution failed, server_id: #{server_id}, ref: #{ref}, reason: #{reason})
      )
    end

    # run any queued command, if any
    GenServer.cast(__MODULE__, {:run_cmd, server_id})

    # removing ref from ref_map and server state
    {:noreply,
     state
     |> Map.put(server_id, %{state[server_id] | running_cmd_task: nil})
     |> Map.put(:ref_map, state.ref_map |> Map.delete(ref))}
  end

  # # The task completed
  @impl true
  def handle_info({_ref, _answer}, state) do
    # demonitor and flush
    # Process.demonitor(ref, [:flush])

    {:noreply, state}
  end

  defp queue_cmd(state, server_id, cmd) do
    state
    |> Map.update(
      server_id,
      %ServerTaskState{} |> ServerTaskState.queue_cmd(cmd),
      fn server_task_state ->
        server_task_state |> ServerTaskState.queue_cmd(cmd)
      end
    )
  end

  defp add_task_log(state, server_id, task_log) do
    state
    |> Map.update(
      server_id,
      %ServerTaskState{} |> ServerTaskState.add_task_log(task_log),
      fn server_task_state ->
        server_task_state |> ServerTaskState.add_task_log(task_log)
      end
    )
  end

  defp run_server_cmd(state = %{timeout: timeout}, server_id) do
    case state[server_id].running_cmd_task do
      # no task is running 
      nil ->
        server_cmd_queue = state[server_id].cmd_queue |> Queue.pop()

        case server_cmd_queue.value do
          # nothing left to run
          nil ->
            state

          # somthing to run exists
          cmd ->
            task =
              case cmd do
                {m, f, a} ->
                  Task.Supervisor.async_nolink(Omc.TaskSupervisor, m, f, a)

                {:command_provider, fun} when is_function(fun, 0) ->
                  fun.() |> async_nolink_cmd(timeout, server_id)

                cmd when is_binary(cmd) ->
                  async_nolink_cmd(cmd, timeout, server_id)
              end

            state
            |> Map.put(
              server_id,
              %{
                state[server_id]
                | cmd_queue: server_cmd_queue,
                  running_cmd_task: task
              }
            )
            |> Map.put(:ref_map, state.ref_map |> Map.put(task.ref, server_id))
        end

      # some command is running for the given server
      _ ->
        state
    end
  end

  defp async_nolink_cmd(cmd, timeout, ref) do
    Task.Supervisor.async_nolink(Omc.TaskSupervisor, CmdWrapper, :run, [
      cmd,
      timeout,
      "server_task_progress",
      ref
    ])
  end
end
