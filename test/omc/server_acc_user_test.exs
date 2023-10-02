defmodule Omc.ServerAccUserTest do
  use Omc.DataCase, async: true
  alias Omc.ServerAccUsers
  import Omc.ServersFixtures
  import Omc.AccountsFixtures
  import Omc.LedgersFixtures

  setup %{} do
    user = user_fixture()
    server = server_fixture(%{user_id: user.id})
    server_acc = server_acc_fixture(%{server_id: server.id})
    activate_server_acc(server, server_acc)
    user_attrs = %{user_type: :telegram, user_id: unique_user_id()}
    %{server: server, server_acc: server_acc, user_attrs: user_attrs}
  end

  describe "allocate server_acc_user tests" do
    test "creates a server_acc_user record with expected fields set/unset", %{
      user_attrs: user_attrs,
      server_acc: server_acc,
      server: server
    } do
      {:ok, server_acc_user} = ServerAccUsers.allocate_new_server_acc_user(user_attrs)
      assert user_attrs.user_type == server_acc_user.user_type
      assert user_attrs.user_id == server_acc_user.user_id
      assert server_acc.id == server_acc_user.server_acc_id
      assert server_acc_user.prices == server.prices
      refute server_acc_user.started_at
      refute server_acc_user.ended_at
      assert happend_now_or_a_second_later(server_acc_user.allocated_at)
    end

    test "if there is no more acc, returns {:error, :no_server_acc_available}", %{
      user_attrs: user_attrs
    } do
      {:ok, _} = ServerAccUsers.allocate_new_server_acc_user(user_attrs)

      assert {:error, :no_server_acc_available} =
               ServerAccUsers.allocate_new_server_acc_user(user_attrs)
    end

    test "create_acc_user on already allocated acc should not be possible", %{
      user_attrs: user_attrs
    } do
      attrs =
        %{server: _server, server_acc: _server_acc} =
        ServerAccUsers.first_available_server_and_acc()

      {:ok, _server_acc_user} =
        ServerAccUsers.create_server_acc_user(attrs |> Map.merge(user_attrs))

      assert {:error, %{errors: [server_acc_id: {"has already been taken", _}]}} =
               ServerAccUsers.create_server_acc_user(attrs |> Map.merge(user_attrs))
    end

    test "get_server_acc_user_allocated/1", %{user_attrs: user_attrs} do
      assert nil == ServerAccUsers.get_server_acc_user_allocated(user_attrs)
      ServerAccUsers.allocate_new_server_acc_user(user_attrs)

      server_acc_user = ServerAccUsers.get_server_acc_user_allocated(user_attrs)

      assert server_acc_user.user_id == user_attrs.user_id
      assert server_acc_user.user_type == user_attrs.user_type
    end

    test "if there exists one allocation, calling allocation again should return existing reallocated",
         %{user_attrs: user_attrs} do
      {:ok, sau1} = ServerAccUsers.allocate_server_acc_user(user_attrs)

      {:ok, dummy_date_sau} =
        sau1
        |> change(%{allocated_at: ~N[2020-01-01 00:00:00]})
        |> Repo.update()

      refute happend_now_or_a_second_later(dummy_date_sau.allocated_at)
      {:ok, sau2} = ServerAccUsers.allocate_server_acc_user(user_attrs)
      assert happend_now_or_a_second_later(sau2.allocated_at)
      assert sau1 == %{sau2 | allocated_at: sau1.allocated_at}
    end

    test "allocated expired accs should be cleanup calling cleanup_acc_allocations/1",
         %{user_attrs: user_attrs} do
      assert ServerAccUsers.get_server_acc_user_allocated(user_attrs) == nil
      ServerAccUsers.allocate_server_acc_user(user_attrs)
      assert ServerAccUsers.get_server_acc_user_allocated(user_attrs) != nil

      # it is still not passed 5 seconds from allocation; then nothing should happen
      ServerAccUsers.cleanup_acc_allocations(5)
      sau = ServerAccUsers.get_server_acc_user_allocated(user_attrs)
      assert sau != nil

      sau
      |> change([allocated_at: sau.allocated_at |> NaiveDateTime.add(-5)])
      |> Repo.update()
      ServerAccUsers.cleanup_acc_allocations(5)
      assert ServerAccUsers.get_server_acc_user_allocated(user_attrs) == nil
    end
  end

  describe "start/stop acc allocation" do
    setup %{user_attrs: user_attrs} do
      {:ok, server_acc_user} = ServerAccUsers.allocate_new_server_acc_user(user_attrs)
      %{server_acc_user: server_acc_user}
    end

    test "starting server_acc_user should set its started_at field",
         %{server_acc_user: sau} do
      # it should be nil before any start operation
      assert sau.started_at == nil
      # it should be set after start operation
      {:ok, %{started_at: started_at}} = ServerAccUsers.start_server_acc_user(sau)
      assert started_at != nil
      # started time shoule be approximately (bearing tollerance of one second) now
      assert happend_now_or_a_second_later(started_at)
    end

    test "ending server_acc_user should set its ended_at field and deactivate server_acc",
         %{server_acc_user: sau} do
      %{server_acc: sa, server_acc_user: update_sau} = ServerAccUsers.end_server_acc_user!(sau)

      assert sa.status == :deactive_pending
      assert happend_now_or_a_second_later(update_sau.ended_at)
    end
  end

  defp happend_now_or_a_second_later(naive_datetime) do
    diff_from_now_in_seconds = NaiveDateTime.utc_now() |> NaiveDateTime.diff(naive_datetime)
    diff_from_now_in_seconds >= 0 and diff_from_now_in_seconds <= 1
  end
end
