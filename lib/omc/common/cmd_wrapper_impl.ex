defmodule Omc.Common.CmdWrapperImpl do
  require Logger
  alias Phoenix.PubSub
  alias Omc.Common.CmdWrapper
  @behaviour CmdWrapper

  def run(cmd, timeout, topic, ref) do
    Logger.info(cmd)
    timeout = timeout || Application.get_env(:omc, :cmd_wrapper)[:timeout]

    task =
      Task.async(fn ->
        port = Port.open({:spawn, cmd}, [:binary, :stderr_to_stdout, :exit_status])

        result = loop(port, "", timeout, topic, ref)

        send(port, {self(), :close})
        result
      end)

    Task.await(task, timeout + 1_000)
  end

  defp loop(port, result, timeout, topic, ref) do
    receive do
      {^port, {:data, data}} ->
        PubSub.broadcast(Omc.PubSub, topic, {:progress, ref, data})
        loop(port, result <> data, timeout, topic, ref)

      {^port, {:exit_status, 0}} ->
        {:ok, result}

      {^port, {:exit_status, 1}} ->
        {:error, result}

      {^port, {:exit_status, _}} ->
        {:unknown, result}
    after
      timeout ->
        {:error, :timeout}
    end
  end
end
