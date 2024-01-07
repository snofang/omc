defmodule Omc.Servers.ServerTaskManagerTest do
  use ExUnit.Case, async: true
  alias Omc.Servers.{ServerTaskManager}
  alias Phoenix.PubSub
  alias Omc.DummyTaskRunner
  import Mox
  import Omc.TestUtils
  @topic "server_task_progress"

  setup %{} do
    start_supervised(ServerTaskManager)
    start_supervised(DummyTaskRunner)
    stub_cmd_wrapper_with_dummy_task()
    :ok
  end

  describe "get_task_log/1" do
    test "no touch servers should empty log" do
      assert ServerTaskManager.get_task_log(123) == ""
    end

    test "broadcasted message should collected" do
      PubSub.broadcast(Omc.PubSub, @topic, {:progress, 1, "a"})
      PubSub.broadcast(Omc.PubSub, @topic, {:progress, 1, "b"})
      PubSub.broadcast(Omc.PubSub, @topic, {:progress, 1, "c"})
      eventual_assert(fn -> ServerTaskManager.get_task_log(1) == "abc" end)
    end

    test "max_log_length_per_server" do
      max_length = Application.get_env(:omc, ServerTaskManager)[:max_log_length_per_server]
      PubSub.broadcast(Omc.PubSub, @topic, {:progress, 1, String.duplicate("a", max_length)})

      eventual_assert(fn -> ServerTaskManager.get_task_log(1) |> String.length() == max_length end)

      PubSub.broadcast(Omc.PubSub, @topic, {:progress, 1, "asdf"})

      eventual_assert(fn -> ServerTaskManager.get_task_log(1) |> String.length() == max_length end)
    end
  end

  describe "run_task/2" do
    test "initial task list is empty" do
      assert ServerTaskManager.get_task_list(123) == []
    end

    test "single server - multi tasks" do
      #
      # #1
      #
      ServerTaskManager.run_task(1, "command1")
      ServerTaskManager.run_task(1, "command2")
      ServerTaskManager.run_task(1, "command3")

      eventual_assert(fn -> DummyTaskRunner.task_running?("command1") end)
      eventual_assert(fn -> ServerTaskManager.get_task_list(1) == ["command3", "command2"] end)
      eventual_assert(fn -> ServerTaskManager.get_task_log(1) == "" end)

      #
      # #2 
      #
      DummyTaskRunner.unblock_task("command1")
      # state
      eventual_assert(fn -> DummyTaskRunner.task_stopped?("command1") end)
      eventual_assert(fn -> DummyTaskRunner.task_running?("command2") end)
      eventual_assert(fn -> ServerTaskManager.get_task_list(1) == ["command3"] end)
      eventual_assert(fn -> ServerTaskManager.get_task_log(1) == "command1" end)

      #
      # #3
      # 
      ServerTaskManager.run_task(1, "command4")
      DummyTaskRunner.unblock_task("command2")
      # state
      eventual_assert(fn -> DummyTaskRunner.task_stopped?("command2") end)
      eventual_assert(fn -> DummyTaskRunner.task_running?("command3") end)
      eventual_assert(fn -> ServerTaskManager.get_task_list(1) == ["command4"] end)
      eventual_assert(fn -> ServerTaskManager.get_task_log(1) == "command1command2" end)

      #
      # #4
      # 
      DummyTaskRunner.unblock_task("command3")
      # state
      eventual_assert(fn -> DummyTaskRunner.task_stopped?("command3") end)
      eventual_assert(fn -> DummyTaskRunner.task_running?("command4") end)
      eventual_assert(fn -> ServerTaskManager.get_task_list(1) == [] end)
      eventual_assert(fn -> ServerTaskManager.get_task_log(1) == "command1command2command3" end)

      #
      # #5
      # 
      DummyTaskRunner.unblock_task("command4")
      # state
      eventual_assert(fn -> DummyTaskRunner.task_stopped?("command4") end)
      eventual_assert(fn -> ServerTaskManager.get_task_list(1) == [] end)

      eventual_assert(fn ->
        ServerTaskManager.get_task_log(1) == "command1command2command3command4"
      end)
    end

    test "multi server - multi tasks" do
      #
      # #1 
      #
      ServerTaskManager.run_task(1, "command1")
      ServerTaskManager.run_task(1, "command2")
      ServerTaskManager.run_task(1, "command3")
      ServerTaskManager.run_task(2, "command4")
      ServerTaskManager.run_task(2, "command5")
      ServerTaskManager.run_task(2, "command6")
      ServerTaskManager.run_task(3, "command7")
      ServerTaskManager.run_task(3, "command8")
      # state 
      eventual_assert(fn -> DummyTaskRunner.task_running?("command1") end)
      eventual_assert(fn -> DummyTaskRunner.task_running?("command4") end)
      eventual_assert(fn -> DummyTaskRunner.task_running?("command7") end)
      eventual_assert(fn -> ServerTaskManager.get_task_list(1) == ["command3", "command2"] end)
      eventual_assert(fn -> ServerTaskManager.get_task_log(1) == "" end)
      eventual_assert(fn -> ServerTaskManager.get_task_list(2) == ["command6", "command5"] end)
      eventual_assert(fn -> ServerTaskManager.get_task_log(2) == "" end)
      eventual_assert(fn -> ServerTaskManager.get_task_list(3) == ["command8"] end)
      eventual_assert(fn -> ServerTaskManager.get_task_log(3) == "" end)

      #
      # #2: 
      #
      DummyTaskRunner.unblock_task("command1")
      DummyTaskRunner.unblock_task("command4")
      ServerTaskManager.run_task(2, "command9")
      # state 
      eventual_assert(fn -> DummyTaskRunner.task_stopped?("command1") end)
      eventual_assert(fn -> DummyTaskRunner.task_stopped?("command4") end)
      eventual_assert(fn -> DummyTaskRunner.task_running?("command2") end)
      eventual_assert(fn -> DummyTaskRunner.task_running?("command5") end)
      eventual_assert(fn -> ServerTaskManager.get_task_list(1) == ["command3"] end)
      eventual_assert(fn -> ServerTaskManager.get_task_log(1) == "command1" end)
      eventual_assert(fn -> ServerTaskManager.get_task_list(2) == ["command9", "command6"] end)
      eventual_assert(fn -> ServerTaskManager.get_task_log(2) == "command4" end)
      eventual_assert(fn -> ServerTaskManager.get_task_list(3) == ["command8"] end)
      eventual_assert(fn -> ServerTaskManager.get_task_log(3) == "" end)

      #
      # #3: 
      #
      DummyTaskRunner.unblock_task("command2")
      DummyTaskRunner.unblock_task("command5")
      DummyTaskRunner.unblock_task("command7")
      # state 
      eventual_assert(fn -> DummyTaskRunner.task_stopped?("command2") end)
      eventual_assert(fn -> DummyTaskRunner.task_stopped?("command5") end)
      eventual_assert(fn -> DummyTaskRunner.task_stopped?("command7") end)
      eventual_assert(fn -> DummyTaskRunner.task_running?("command3") end)
      eventual_assert(fn -> DummyTaskRunner.task_running?("command6") end)
      eventual_assert(fn -> DummyTaskRunner.task_running?("command8") end)
      eventual_assert(fn -> ServerTaskManager.get_task_list(1) == [] end)
      eventual_assert(fn -> ServerTaskManager.get_task_log(1) == "command1command2" end)
      eventual_assert(fn -> ServerTaskManager.get_task_list(2) == ["command9"] end)
      eventual_assert(fn -> ServerTaskManager.get_task_log(2) == "command4command5" end)
      eventual_assert(fn -> ServerTaskManager.get_task_list(3) == [] end)
      eventual_assert(fn -> ServerTaskManager.get_task_log(3) == "command7" end)

      #
      # #4: 
      #
      DummyTaskRunner.unblock_task("command3")
      DummyTaskRunner.unblock_task("command6")
      DummyTaskRunner.unblock_task("command8")
      # state 
      eventual_assert(fn -> DummyTaskRunner.task_stopped?("command3") end)
      eventual_assert(fn -> DummyTaskRunner.task_stopped?("command6") end)
      eventual_assert(fn -> DummyTaskRunner.task_stopped?("command8") end)
      eventual_assert(fn -> DummyTaskRunner.task_running?("command9") end)
      eventual_assert(fn -> ServerTaskManager.get_task_list(1) == [] end)
      eventual_assert(fn -> ServerTaskManager.get_task_log(1) == "command1command2command3" end)
      eventual_assert(fn -> ServerTaskManager.get_task_list(2) == [] end)
      eventual_assert(fn -> ServerTaskManager.get_task_log(2) == "command4command5command6" end)
      eventual_assert(fn -> ServerTaskManager.get_task_list(3) == [] end)
      eventual_assert(fn -> ServerTaskManager.get_task_log(3) == "command7command8" end)

      #
      # #5: 
      #
      DummyTaskRunner.unblock_task("command9")
      # state 
      eventual_assert(fn -> DummyTaskRunner.task_stopped?("command9") end)
      eventual_assert(fn -> ServerTaskManager.get_task_list(1) == [] end)
      eventual_assert(fn -> ServerTaskManager.get_task_log(1) == "command1command2command3" end)
      eventual_assert(fn -> ServerTaskManager.get_task_list(2) == [] end)

      eventual_assert(fn ->
        ServerTaskManager.get_task_log(2) == "command4command5command6command9"
      end)

      eventual_assert(fn -> ServerTaskManager.get_task_list(3) == [] end)
      eventual_assert(fn -> ServerTaskManager.get_task_log(3) == "command7command8" end)
    end

    test "mfa support" do
      mfa = {Omc.Common.CmdWrapper, :run, ["command1", 1000, @topic, 1]}
      ServerTaskManager.run_task(1, mfa)
      eventual_assert(fn -> DummyTaskRunner.task_running?("command1") end)
      DummyTaskRunner.unblock_task("command1")
      eventual_assert(fn -> DummyTaskRunner.task_stopped?("command1") end)
      eventual_assert(fn -> ServerTaskManager.get_task_log(1) == "command1" end)
    end

    test "run_task_by_command_provider support" do
      ServerTaskManager.run_task_by_command_provider(1, fn -> "command1" end)
      eventual_assert(fn -> DummyTaskRunner.task_running?("command1") end)
      DummyTaskRunner.unblock_task("command1")
      eventual_assert(fn -> DummyTaskRunner.task_stopped?("command1") end)
      eventual_assert(fn -> ServerTaskManager.get_task_log(1) == "command1" end)
    end
  end

  describe "get_task_list/1" do
    test "no server state" do
      assert ServerTaskManager.get_task_list(1) == []
    end
  end

  describe "cancel_running_task/1" do
    test "no server - no effect" do
      ServerTaskManager.cancel_running_task(1)
    end

    test "running task" do
      #
      # #1
      #
      ServerTaskManager.run_task(1, "command1")
      ServerTaskManager.run_task(1, "command2")
      eventual_assert(fn -> DummyTaskRunner.task_running?("command1") end)
      eventual_assert(fn -> ServerTaskManager.get_task_list(1) == ["command2"] end)
      #
      # #2
      #
      ServerTaskManager.cancel_running_task(1)
      eventual_assert(fn -> ServerTaskManager.get_task_list(1) == [] end)
      eventual_assert(fn -> DummyTaskRunner.task_running?("command2") end)
      #
      # #3
      #
      DummyTaskRunner.unblock_task("command2")
      eventual_assert(fn -> DummyTaskRunner.task_stopped?("command2") end)
    end
  end

  defp stub_cmd_wrapper_with_dummy_task() do
    Omc.CmdWrapperMock
    |> stub(:run, fn cmd, _timeout, topic, ref ->
      DummyTaskRunner.run_block_task(cmd)
      PubSub.broadcast(Omc.PubSub, topic, {:progress, ref, cmd})
      {:ok, "collective-result"}
    end)
    |> allow(self(), Process.whereis(ServerTaskManager))
  end
end
