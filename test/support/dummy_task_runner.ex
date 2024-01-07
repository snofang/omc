defmodule Omc.DummyTaskRunner do
  @doc """
  Use this to create controlled blocking tasks which can be unblocked on demand.
  It is just for tests.
  """
  use GenServer

  def run_block_task(cmd) do
    GenServer.call(__MODULE__, {:put_state, cmd, :started})
    process(cmd)
    GenServer.call(__MODULE__, {:put_state, cmd, :stopped})
  end

  def unblock_task(cmd) do
    GenServer.call(__MODULE__, {:put_state, cmd, :stop})
  end

  def task_running?(cmd) do
    GenServer.call(__MODULE__, {:get_state, cmd}) == :running
  end

  def task_stopped?(cmd) do
    GenServer.call(__MODULE__, {:get_state, cmd}) == :stopped
  end

  def start_link(_args) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @impl true
  def init(nil) do
    {:ok, Map.new()}
  end

  @impl true
  def handle_call({:put_state, cmd, cmd_state}, _from, state) do
    {:reply, :ok, state |> Map.put(cmd, cmd_state)}
  end

  @impl true
  def handle_call({:get_state, cmd}, _from, state) do
    {:reply, state |> Map.get(cmd), state}
  end

  defp process(cmd) do
    case GenServer.call(__MODULE__, {:get_state, cmd}) do
      :started ->
        GenServer.call(__MODULE__, {:put_state, cmd, :running})
        Process.sleep(50)
        process(cmd)

      :running ->
        Process.sleep(50)
        process(cmd)

      :stop ->
        nil
    end
  end
end
