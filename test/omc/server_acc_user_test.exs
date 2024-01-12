defmodule Omc.ServerAccUserTest do
  alias Omc.PricePlans
  alias Ecto.StaleEntryError
  alias Omc.TestUtils
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
      server_acc: server_acc
    } do
      {:ok, server_acc_user} = ServerAccUsers.allocate_new_server_acc_user(user_attrs)
      assert user_attrs.user_type == server_acc_user.user_type
      assert user_attrs.user_id == server_acc_user.user_id
      assert server_acc.id == server_acc_user.server_acc_id
      refute server_acc_user.started_at
      refute server_acc_user.ended_at
      assert TestUtils.happend_now_or_a_second_later(server_acc_user.allocated_at)
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

      refute TestUtils.happend_now_or_a_second_later(dummy_date_sau.allocated_at)
      {:ok, sau2} = ServerAccUsers.allocate_server_acc_user(user_attrs)
      assert TestUtils.happend_now_or_a_second_later(sau2.allocated_at)

      assert sau1 ==
               sau2
               |> Map.replace(:allocated_at, sau1.allocated_at)
               |> Map.replace(:lock_version, sau1.lock_version)
               |> Map.replace(:updated_at, sau1.updated_at)
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
      |> change(allocated_at: sau.allocated_at |> NaiveDateTime.add(-5))
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

      # adding dome credit
      ledger_tx_fixture!(%{user_id: sau.user_id, user_type: sau.user_type})

      # it should be set after start operation
      {:ok, %{started_at: started_at}} = ServerAccUsers.start_server_acc_user(sau)
      assert started_at != nil
      # started time shoule be approximately (bearing tollerance of one second) now
      assert TestUtils.happend_now_or_a_second_later(started_at)
    end

    test "starting already started sau should prevented",
         %{server_acc_user: sau} do
      # adding some credit
      ledger_tx_fixture!(%{user_id: sau.user_id, user_type: sau.user_type})
      {:ok, started_sau} = ServerAccUsers.start_server_acc_user(sau)
      assert_raise StaleEntryError, fn -> ServerAccUsers.start_server_acc_user(sau) end

      assert_raise FunctionClauseError, fn ->
        ServerAccUsers.start_server_acc_user(started_sau)
      end
    end

    test "it should not be possible to end server_acc_user if not started",
         %{server_acc_user: sau} do
      {:error,
       %{
         errors: [
           started_at: {"It's not possible to end a server_acc_user, when not started", []}
         ]
       }} = ServerAccUsers.end_server_acc_user(sau)
    end

    test "ending server_acc_user should set its ended_at field",
         %{server_acc_user: sau} do
      # adding some credit
      ledger_tx_fixture!(%{user_id: sau.user_id, user_type: sau.user_type})
      {:ok, sau} = ServerAccUsers.start_server_acc_user(sau)

      {:ok, sau} = ServerAccUsers.end_server_acc_user(sau)

      assert TestUtils.happend_now_or_a_second_later(sau.ended_at)
    end
  end

  describe "list_server_tags_with_free_accs_count/0" do
    test "server having active acc should listed", %{server: server} do
      tag = server.tag
      assert [%{tag: ^tag, count: 1}] = ServerAccUsers.list_server_tags_with_free_accs_count()
    end

    test "server without active acc should not listed", %{server: server} do
      server_fixture()
      tag = server.tag
      assert [%{tag: ^tag, count: 1}] = ServerAccUsers.list_server_tags_with_free_accs_count()
    end

    test "servers having same price and tag should grouped", %{server: server} do
      price_plan = server.price_plan
      server2 = server_fixture(%{price_plan_id: price_plan.id})

      server_acc_fixture(%{server_id: server2.id})
      |> then(fn acc -> activate_server_acc(server2, acc) end)

      tag = server.tag

      assert [%{tag: ^tag, price_plan: ^price_plan, count: 2}] =
               ServerAccUsers.list_server_tags_with_free_accs_count()
    end

    test "servers having same price but different tags, grouped separately", %{server: server} do
      server2 = server_fixture(%{tag: "here-there", price_plan_id: server.price_plan.id})

      server_acc_fixture(%{server_id: server2.id})
      |> then(fn acc -> activate_server_acc(server2, acc) end)

      server_acc_fixture(%{server_id: server2.id})
      |> then(fn acc -> activate_server_acc(server2, acc) end)

      list = ServerAccUsers.list_server_tags_with_free_accs_count()
      assert list |> length() == 2

      assert list
             |> Enum.find(fn %{tag: tag, count: count} -> tag == server.tag and count == 1 end)

      assert list
             |> Enum.find(fn %{tag: tag, count: count} -> tag == "here-there" and count == 2 end)
    end

    test "servers having same tag but different prices, grouped separately", %{server: server} do
      server2 = server_fixture()

      server_acc_fixture(%{server_id: server2.id})
      |> then(fn acc -> activate_server_acc(server2, acc) end)

      server_acc_fixture(%{server_id: server2.id})
      |> then(fn acc -> activate_server_acc(server2, acc) end)

      list = ServerAccUsers.list_server_tags_with_free_accs_count()
      assert list |> length() == 2

      assert list
             |> Enum.find(fn %{tag: tag, price_plan: price_plan, count: count} ->
               tag == server.tag and count == 1 and price_plan == server.price_plan
             end)

      assert list
             |> Enum.find(fn %{tag: tag, price_plan: price_plan, count: count} ->
               tag == server2.tag and count == 2 and price_plan == server2.price_plan
             end)
    end
  end

  describe "first_available_server_and_acc/1" do
    test "one server, one active acc, no filter", %{
      server: %{id: server_id},
      server_acc: %{id: server_acc_id}
    } do
      assert %{server: %{id: ^server_id}, server_acc: %{id: ^server_acc_id}} =
               ServerAccUsers.first_available_server_and_acc()
    end

    test "not activated acc should not be returned" do
      server1 = server_fixture(%{tag: "server1-tag"})
      _server_acc1 = server_acc_fixture(%{server_id: server1.id})
      assert ServerAccUsers.first_available_server_and_acc(server_tag: "server1-tag") == nil
    end

    test "different server tags", %{
      server: %{tag: server_tag},
      server_acc: %{id: server_acc_id}
    } do
      assert %{server: _server, server_acc: %{id: ^server_acc_id}} =
               ServerAccUsers.first_available_server_and_acc(server_tag: server_tag)

      %{id: server1_id} = server1 = server_fixture(%{tag: "server1-tag"})
      %{id: server_acc1_id} = server_acc1 = server_acc_fixture(%{server_id: server1_id})
      activate_server_acc(server1, server_acc1)

      assert %{server: %{id: ^server1_id}, server_acc: %{id: ^server_acc1_id}} =
               ServerAccUsers.first_available_server_and_acc(server_tag: "server1-tag")
    end

    test "same server tags, different price plans", %{
      server: %{id: server_id, tag: server_tag, price_plan_id: price_plan_id},
      server_acc: %{id: server_acc_id}
    } do
      {:ok, %{id: price_plan_id2}} = PricePlans.create_price_plan(Money.new(1234))
      %{id: server1_id} = server1 = server_fixture(%{price_plan_id: price_plan_id2})
      %{id: server_acc1_id} = server_acc1 = server_acc_fixture(%{server_id: server1_id})
      activate_server_acc(server1, server_acc1)

      assert %{server: %{id: ^server1_id}, server_acc: %{id: ^server_acc1_id}} =
               ServerAccUsers.first_available_server_and_acc(price_plan_id: price_plan_id2)

      assert %{server: %{id: ^server1_id}, server_acc: %{id: ^server_acc1_id}} =
               ServerAccUsers.first_available_server_and_acc(
                 price_plan_id: price_plan_id2,
                 server_tag: server_tag
               )

      assert %{server: %{id: ^server_id}, server_acc: %{id: ^server_acc_id}} =
               ServerAccUsers.first_available_server_and_acc(
                 price_plan_id: price_plan_id,
                 server_tag: server_tag
               )
    end
  end

  describe "get_server_accs_in_use/1" do
    setup %{user_attrs: user_attrs} do
      ledger_tx_fixture!(user_attrs)
      {:ok, server_acc_user} = ServerAccUsers.allocate_new_server_acc_user(user_attrs)
      %{server_acc_user: server_acc_user}
    end

    test "no in-use server_acc", %{user_attrs: user} do
      assert [] = ServerAccUsers.get_server_accs_in_use(user)
    end

    test "one server_acc in use", %{
      user_attrs: user,
      server_acc_user: sau = %{id: sau_id},
      server_acc: %{id: sa_id},
      server: %{id: s_id, tag: server_tag}
    } do
      ServerAccUsers.start_server_acc_user(sau)

      assert [%{s_id: ^s_id, sa_id: ^sa_id, sau_id: ^sau_id, s_tag: ^server_tag}] =
               ServerAccUsers.get_server_accs_in_use(user)
    end
  end
end
