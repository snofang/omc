defmodule Omc.UsagesTest do
  alias Phoenix.PubSub
  alias Omc.ServersFixtures
  alias Omc.LedgersFixtures
  alias Omc.ServerAccUsers
  alias Omc.TestUtils
  alias Omc.Ledgers
  use Omc.DataCase, async: true
  alias Omc.Usages
  alias Omc.Ledgers.Ledger
  import Omc.UsagesFixtures

  @server_price Money.new(100_00)
  @initial_credit Money.new(50_00)

  describe "usage_state/1 tests" do
    setup :setup_a_usage_started

    test "5 days usage credit check", %{usage: usage, ledger: ledger} do
      usage_duration_use_fixture(usage, 5, :day)

      computed_money_credit =
        ledger
        |> Usages.get_user_usage_state()
        |> get_in([Access.key(:ledgers), Access.at(0)])
        |> Ledger.credit_money()

      assert @initial_credit
             |> Money.subtract((@server_price.amount * 5 / 30) |> round())
             |> Money.compare(computed_money_credit) == 0
    end

    test "single user, multiple usages, full credit consumption", %{
      usage: usage,
      ledger: ledger,
      server: server
    } do
      # 4 usage, 15 days consumption 
      usage_duration_use_fixture(usage, 5, :day)

      usage_fixture(%{server: server, user_attrs: ledger})
      |> usage_duration_use_fixture(6, :day)

      usage_fixture(%{server: server, user_attrs: ledger})
      |> usage_duration_use_fixture(1, :day)

      usage_fixture(%{server: server, user_attrs: ledger})
      |> usage_duration_use_fixture(3, :day)

      usage_state = Usages.get_user_usage_state(ledger)
      assert get_in(usage_state.ledgers, [Access.at(0), Access.key(:credit)]) == 0
    end
  end

  describe "usage_state_persist/1" do
    setup :setup_a_usage_started

    test "minimum duration usage - 1 second", %{
      usage: usage,
      ledger: ledger
    } do
      usage_duration_use_fixture(usage, 1, :second)

      # compute usage_state
      usage_state = Usages.get_user_usage_state(ledger)
      assert usage_state.changesets |> length() == 1

      # trying to persis eligible changesets
      Usages.persist_usage_state!(usage_state, all: true)
      # recompute changeset
      usage_state = Usages.get_user_usage_state(ledger)
      assert usage_state.changesets |> length() == 1
    end

    test "5 days usage state should not cause any persistance", %{
      usage: usage,
      ledger: ledger
    } do
      usage_duration_use_fixture(usage, 5, :day)

      # compute usage_state
      usage_state = Usages.get_user_usage_state(ledger)
      assert usage_state.changesets |> length() == 1
      # trying to persis eligible changesets
      Usages.persist_usage_state!(usage_state)
      # recompute changeset
      usage_state = Usages.get_user_usage_state(ledger)
      assert usage_state.changesets |> length() == 1
    end

    test "5 days usage state should not cause persistance having all: true", %{
      usage: usage,
      ledger: ledger
    } do
      usage_duration_use_fixture(usage, 5, :day)

      # compute usage_state
      usage_state = Usages.get_user_usage_state(ledger)
      assert usage_state.changesets |> length() == 1
      # trying to persis eligible changesets
      Usages.persist_usage_state!(usage_state, all: true)
      # recompute changeset
      usage_state = Usages.get_user_usage_state(ledger)
      assert usage_state.changesets |> length() == 0
    end

    test "20 days usage state should cause two persistance items", %{
      usage: usage,
      ledger: ledger
    } do
      usage_duration_use_fixture(usage, 20, :day)

      # compute usage_state
      usage_state = Usages.get_user_usage_state(ledger)
      assert usage_state.changesets |> length() == 2
      # trying to persis eligible changesets
      Usages.persist_usage_state!(usage_state)
      # recompute changeset
      usage_state = Usages.get_user_usage_state(ledger)
      assert usage_state.changesets |> length() == 0
      assert Ledgers.get_ledger(ledger) |> then(& &1.credit) < 0
      assert usage_state.usages |> length() == 1
      assert usage_state.usages |> Enum.at(0) |> then(& &1.usage_items) |> length() == 2

      usage_item1 =
        assert usage_state.usages |> Enum.at(0) |> then(& &1.usage_items) |> Enum.at(0)

      usage_item2 =
        assert usage_state.usages |> Enum.at(0) |> then(& &1.usage_items) |> Enum.at(1)

      [tx3, tx2, tx1] = Ledgers.get_ledger_txs(ledger)
      assert tx3.context == :usage
      assert tx3.context_id == usage_item2.id
      assert tx3.amount == (@initial_credit.amount / 3) |> round()
      assert tx3.type == :debit

      assert tx2.context == :usage
      assert tx2.context_id == usage_item1.id
      assert tx2.amount == @initial_credit.amount
      assert tx2.type == :debit

      assert tx1.context == :manual
      assert tx1.amount == @initial_credit.amount
      assert tx1.type == :credit
    end

    test "single user, four usages, full credit consumption, four persistance", %{
      usage: usage,
      ledger: ledger,
      server: server
    } do
      # 4 usage, 15 days consumption 
      usage_duration_use_fixture(usage, 5, :day)

      usage_fixture(%{server: server, user_attrs: ledger})
      |> usage_duration_use_fixture(6, :day)

      usage_fixture(%{server: server, user_attrs: ledger})
      |> usage_duration_use_fixture(1, :day)

      usage_fixture(%{server: server, user_attrs: ledger})
      |> usage_duration_use_fixture(3, :day)

      # compute usage_state
      usage_state = Usages.get_user_usage_state(ledger)
      assert usage_state.changesets |> length() == 4

      # persisting
      Usages.persist_usage_state!(usage_state)

      # recompute changeset
      usage_state = Usages.get_user_usage_state(ledger)
      assert usage_state.changesets |> length() == 0
      assert Ledgers.get_ledger(ledger) |> then(& &1.credit) == 0
    end
  end

  describe "get_active_users/0 test" do
    setup :setup_a_usage_started

    test "single user multiple usages", %{server: server, ledger: ledger} do
      # already have one usage by setup
      [active_user] = Usages.get_active_users()
      assert ledger.user_id == active_user.user_id
      assert ledger.user_type == active_user.user_type

      # adding another usage to the same user
      usage_fixture(%{server: server, user_attrs: ledger})
      assert Usages.get_active_users() == [active_user]
    end

    test "multiple users multiple usages", %{server: server, ledger: ledger} do
      # adding another usage to setuped user
      usage_fixture(%{server: server, user_attrs: ledger})

      # setting up another user and it usages
      ledger1 = ledger_fixture(@initial_credit)
      usage_fixture(%{server: server, user_attrs: ledger1})
      usage_fixture(%{server: server, user_attrs: ledger1})

      active_users = Usages.get_active_users()
      assert active_users |> length() == 2
      assert active_users |> get_in([Access.at(0), Access.key(:user_id)]) == ledger.user_id
      assert active_users |> get_in([Access.at(1), Access.key(:user_id)]) == ledger1.user_id
    end

    test "users without usages should not be listed", %{server: server, ledger: ledger} do
      # adding another usage to setuped user
      usage_fixture(%{server: server, user_attrs: ledger})

      # setting up another user and it usages
      ledger_fixture(@initial_credit)

      active_users = Usages.get_active_users()
      assert active_users |> length() == 1
      assert active_users |> get_in([Access.at(0), Access.key(:user_id)]) == ledger.user_id
    end

    test "paging test", %{server: server, ledger: ledger} do
      # setting up another user and it usages
      ledger1 = ledger_fixture(@initial_credit)
      usage_fixture(%{server: server, user_attrs: ledger1})

      # setting up another user and it usages
      ledger2 = ledger_fixture(@initial_credit)
      usage_fixture(%{server: server, user_attrs: ledger2})

      active_users = Usages.get_active_users(1, 1)
      assert active_users |> length() == 1
      assert active_users |> get_in([Access.at(0), Access.key(:user_id)]) == ledger.user_id

      active_users = Usages.get_active_users(2, 1)
      assert active_users |> length() == 1
      assert active_users |> get_in([Access.at(0), Access.key(:user_id)]) == ledger1.user_id

      active_users = Usages.get_active_users(3, 1)
      assert active_users |> length() == 1
      assert active_users |> get_in([Access.at(0), Access.key(:user_id)]) == ledger2.user_id
    end

    test "users who's usage ended should not be listed", %{server: _server, ledger: _ledger} do
      # TODO: implement this after usage ending functionality developed
    end
  end

  describe "update_usage_states/0 tests" do
    setup :setup_a_usage_started

    test "usage which their state are eligible for update, should be updated", %{
      server: server,
      usage: usage,
      ledger: ledger
    } do
      # fixing all credit consuption.
      usage_duration_use_fixture(usage, 15, :day)
      # Another user, usages, one day consumption.
      ledger1 = ledger_fixture(@initial_credit)
      usage1 = usage_fixture(%{server: server, user_attrs: ledger1})
      usage_duration_use_fixture(usage1, 1, :day)

      Usages.update_usage_states()
      assert Ledgers.get_ledger(ledger) |> Map.get(:credit) == 0
      assert Ledgers.get_ledger(ledger1) |> Map.get(:credit) == @initial_credit.amount
    end

    test "single user, multiple usages, total credit consumption", %{
      server: server,
      usage: usage,
      ledger: ledger
    } do
      # fixing all credit consuption.
      usage_duration_use_fixture(usage, 15, :day)
      # Another user, usages, one day consumption.
      ledger1 = ledger_fixture(@initial_credit)
      usage1 = usage_fixture(%{server: server, user_attrs: ledger1})
      usage_duration_use_fixture(usage1, 1, :day)

      Usages.update_usage_states()
      assert Ledgers.get_ledger(ledger) |> Map.get(:credit) == 0
      assert Ledgers.get_ledger(ledger1) |> Map.get(:credit) == @initial_credit.amount
    end

    test "all usage_states are computed & updated (tail call test)", %{
      server: server,
      usage: usage,
      ledger: ledger
    } do
      # fixing all credit consuption.
      usage_duration_use_fixture(usage, 15, :day)
      # another user and usages; fixing all credit consuption.
      ledger1 = ledger_fixture(@initial_credit)
      usage1 = usage_fixture(%{server: server, user_attrs: ledger1})
      usage_duration_use_fixture(usage1, 15, :day)
      # another user and usages; fixing all credit consuption.
      ledger2 = ledger_fixture(@initial_credit)
      usage2 = usage_fixture(%{server: server, user_attrs: ledger2})
      usage_duration_use_fixture(usage2, 15, :day)

      Usages.update_usage_states(1, 1)

      assert Ledgers.get_ledger(ledger) |> Map.get(:credit) == 0
      assert Ledgers.get_ledger(ledger1) |> Map.get(:credit) == 0
      assert Ledgers.get_ledger(ledger2) |> Map.get(:credit) == 0
    end
  end

  describe "Omc.Usages.end_usage/1" do
    setup :setup_a_usage_started

    test "ending usage should end usage, server_user_acc, and server_acc", %{
      usage: usage,
      ledger: ledger
    } do
      {:ok, %{usage_and_state: %{usage: usage_ended}}} =
        usage
        |> usage_duration_use_fixture(1, :day)
        |> Usages.end_usage()

      assert usage_ended.ended_at |> TestUtils.happend_now_or_a_second_later()

      # usage state
      usage_state = Usages.get_user_usage_state(Ledger.user_attrs(ledger))
      assert usage_state.ledgers |> List.first() |> Map.get(:credit) < @initial_credit.amount
      assert usage_state.usages == []
      assert usage_state.changesets == []

      # server_user_acc
      sau = ServerAccUsers.get_server_acc_user(usage.server_acc_user_id)
      assert TestUtils.happend_now_or_a_second_later(sau.ended_at)
    end

    test "multiple usages, ending one should not affect the others", %{
      usage: usage,
      ledger: ledger,
      server: server
    } do
      # three usages for one user
      usage
      |> usage_duration_use_fixture(1, :day)

      usage1 =
        usage_fixture(%{server: server, user_attrs: ledger})
        |> usage_duration_use_fixture(2, :day)

      usage_fixture(%{server: server, user_attrs: ledger})
      |> usage_duration_use_fixture(3, :day)

      # ending one of them
      {:ok, _} = Usages.end_usage(usage1)

      # usage state
      usage_state = Usages.get_user_usage_state(Ledger.user_attrs(ledger))
      assert usage_state.ledgers |> List.first() |> Map.get(:credit) < @initial_credit.amount
      assert usage_state.usages |> length() == 2
      assert usage_state.changesets |> length() == 2
    end
  end

  describe "Omc.Usages.get_active_no_credit_usages/0" do
    setup :setup_a_usage_started

    test "should return usages which their users have not credit after `update_usage_states/0`",
         %{
           server: server,
           usage: usage
         } do
      # default usage more than full usage; making its credit negative
      usage
      |> usage_duration_use_fixture(20, :day)

      # another user having two usages; fixing all credit consuption.
      ledger1 = ledger_fixture(@initial_credit)

      usage1 =
        usage_fixture(%{server: server, user_attrs: ledger1})
        |> usage_duration_use_fixture(10, :day)

      usage2 =
        usage_fixture(%{server: server, user_attrs: ledger1})
        |> usage_duration_use_fixture(5, :day)

      # another user having two usages; fixing under credit consuption.
      ledger2 = ledger_fixture(@initial_credit)

      usage_fixture(%{server: server, user_attrs: ledger2})
      |> usage_duration_use_fixture(1, :day)

      usage_fixture(%{server: server, user_attrs: ledger2})
      |> usage_duration_use_fixture(5, :day)

      # berfor `update_usage_states/0` there should be no result
      assert Usages.get_active_no_credit_usages() |> length() == 0

      # after `update_usage_states/0`
      Usages.update_usage_states()
      usages = Usages.get_active_no_credit_usages()
      assert usages |> length() == 3
      assert get_in(usages, [Access.at(0), Access.key(:id)]) == usage.id
      assert get_in(usages, [Access.at(1), Access.key(:id)]) == usage1.id
      assert get_in(usages, [Access.at(2), Access.key(:id)]) == usage2.id
    end
  end

  describe "Omc.Usages.end_usages_with_no_credit/0" do
    setup :setup_a_usage_started

    test "a usage with no credit should ended", %{usage: usage, server: %{id: server_id}} do
      usage
      |> usage_duration_use_fixture(15, :day)

      Usages.update_usage_states()
      Phoenix.PubSub.subscribe(Omc.PubSub, "server-tasks")
      Usages.end_usages_with_no_credit()

      # it's just calls `Servers.deactivate_acc/1` and usage ending happening at effective deactivation.
      assert %{status: :deactive_pending} = Usages.get_server_acc_by_usage(usage)

      # making sure that deactivation is happening via correct execution path and not just updating.
      assert_receive({:sync_accs_server_task, ^server_id})
    end

    test "all no credit usages are considered (tail call test)", %{
      server: server,
      usage: usage
    } do
      # default usage, all credit consumption
      u1 = usage_duration_use_fixture(usage, 15, :day)

      # another user and usages; fixing more than credit consumption.
      ledger1 = ledger_fixture(@initial_credit)

      u2 =
        usage_fixture(%{server: server, user_attrs: ledger1})
        |> usage_duration_use_fixture(20, :day)

      # another user and usages; fixing all credit consuption.
      ledger2 = ledger_fixture(@initial_credit)

      u3 =
        usage_fixture(%{server: server, user_attrs: ledger2})
        |> usage_duration_use_fixture(5, :day)

      u4 =
        usage_fixture(%{server: server, user_attrs: ledger2})
        |> usage_duration_use_fixture(7, :day)

      u5 =
        usage_fixture(%{server: server, user_attrs: ledger2})
        |> usage_duration_use_fixture(6, :day)

      Usages.update_usage_states()
      Usages.end_usages_with_no_credit(1, 1)

      assert %{status: :deactive_pending} = Usages.get_server_acc_by_usage(u1)
      assert %{status: :deactive_pending} = Usages.get_server_acc_by_usage(u2)
      assert %{status: :deactive_pending} = Usages.get_server_acc_by_usage(u3)
      assert %{status: :deactive_pending} = Usages.get_server_acc_by_usage(u4)
      assert %{status: :deactive_pending} = Usages.get_server_acc_by_usage(u5)
    end
  end

  describe "Omc.Usages.get_active_expired_usages/2" do
    setup :setup_a_usage_started

    test "should return expired usages", %{usage: usage, server: server} do
      # default usage, less than price duration usage
      usage_duration_use_fixture(usage, 29, :day)
      assert Usages.get_active_expired_usages() |> length() == 0

      # default usage, duraiton usage
      usage_duration_use_fixture(usage, 30, :day)
      assert Usages.get_active_expired_usages() |> length() == 1

      # another user and usages; less and more than duration
      ledger1 = ledger_fixture(@initial_credit |> Money.multiply(2))

      usage_fixture(%{server: server, user_attrs: ledger1})
      |> usage_duration_use_fixture(20, :day)

      usage_fixture(%{server: server, user_attrs: ledger1})
      |> usage_duration_use_fixture(39, :day)

      assert Usages.get_active_expired_usages() |> length() == 2
    end
  end

  describe "Omc.Usages.renew/1" do
    setup :setup_a_usage_started

    test "should end usage, create new one starting from now", %{usage: usage, ledger: ledger} do
      {:ok, %{usage: new_usage}} =
        usage
        |> usage_duration_use_fixture(5, :day)
        |> Usages.renew_usage()

      usage_state = Usages.get_user_usage_state(ledger)

      # ledgers credit updated
      assert usage_state.ledgers
             |> List.first()
             |> (& &1.credit).() < @initial_credit.amount

      # same usage result from ending as the one got from usage_state
      assert_usages_equal(new_usage, usage_state.usages |> List.first())

      # different id; realy new one creted 
      assert new_usage.id != usage.id

      # started_at now
      assert new_usage.started_at |> TestUtils.happend_now_or_a_second_later()

      # same server_acc_user_id
      assert new_usage.server_acc_user_id == usage.server_acc_user_id
    end
  end

  describe "Omc.Usages.renew_usages_expired" do
    setup :setup_a_usage_started

    test "expired usages should renewed", %{usage: usage, ledger: ledger} do
      usage_duration_use_fixture(usage, 30, :day)
      Usages.renew_usages_expired()

      # there should exist a usage strted now
      assert get_in(Usages.get_user_usage_state(ledger), [
               Access.key(:usages),
               Access.at(0),
               Access.key(:started_at)
             ])
             |> TestUtils.happend_now_or_a_second_later()
    end

    test "all expired usages should renewed(tail call test)", %{
      usage: usage,
      ledger: ledger,
      server: server
    } do
      # increasing user's credit; it should now have credit for 3.5 months
      ledger_tx_fixture(ledger, @initial_credit |> Money.multiply(6))

      usage_duration_use_fixture(usage, 30, :day)

      # another expired usage
      usage_fixture(%{server: server, user_attrs: ledger})
      |> usage_duration_use_fixture(32, :day)

      # another expired usage
      usage_fixture(%{server: server, user_attrs: ledger})
      |> usage_duration_use_fixture(30, :day)

      Usages.renew_usages_expired(1, 1)

      # there should exist a usage strted now
      assert Usages.get_user_usage_state(ledger)
             |> then(& &1.usages)
             |> Enum.reduce(
               true,
               &(TestUtils.happend_now_or_a_second_later(&1.started_at) and &2)
             )
    end
  end

  describe "Omc.Usages.update_usages/0" do
    setup :setup_a_usage_started

    test "in one run updates ledgers, close no-credit usages, and renew expired ones", %{
      usage: usage,
      server: server
    } do
      # making default one as a candidate of close no-credit
      u1 = usage_duration_use_fixture(usage, 15, :day)

      # setting up another user; more than 30 days credit, renew candidate
      ledger1 = ledger_fixture(@initial_credit |> Money.multiply(3))

      renew_usage =
        usage_fixture(%{server: server, user_attrs: ledger1})
        |> usage_duration_use_fixture(30, :day)

      no_change_usage =
        usage_fixture(%{server: server, user_attrs: ledger1})
        |> usage_duration_use_fixture(5, :day)

      Usages.update_usages()

      # effective usage closure is happening gradually when effective acc deactivation happens
      assert %{status: :deactive_pending} = Usages.get_server_acc_by_usage(u1)

      usage_state1 = Usages.get_user_usage_state(ledger1)

      # no change usage
      assert_usages_equal(get_in(usage_state1.usages, [Access.at(0)]), no_change_usage)

      assert get_in(usage_state1.usages, [Access.at(1), Access.key(:started_at)])
             |> TestUtils.happend_now_or_a_second_later()

      assert get_in(usage_state1.usages, [Access.at(1), Access.key(:server_acc_user_id)]) ==
               renew_usage.server_acc_user_id
    end
  end

  describe "start_usage/1" do
    test "without credit - failed_value: :no_credit" do
      server = server_fixture(@server_price)
      server_acc = ServersFixtures.server_acc_fixture(%{server_id: server.id})
      ServersFixtures.activate_server_acc(server, server_acc)
      user = LedgersFixtures.unique_user_attrs()
      assert Usages.start_usage(user) == {:error, :no_credit}
    end

    test "minimum credit " do
      server = server_fixture(@server_price)
      server_acc = ServersFixtures.server_acc_fixture(%{server_id: server.id})
      ServersFixtures.activate_server_acc(server, server_acc)
      ledger = ledger_fixture(Money.new(1))
      assert {:ok, _} = Usages.start_usage(ledger)
    end

    test "existing usage duration + acc_min_usage_days = 15 days" do
      server = server_fixture(@server_price)
      ledger = ledger_fixture(@initial_credit)

      # first usage
      sa1 = ServersFixtures.server_acc_fixture(%{server_id: server.id})
      ServersFixtures.activate_server_acc(server, sa1)
      {:ok, %{usage: usage}} = Usages.start_usage(ledger)

      usage_duration_use_fixture(
        usage,
        15 - Application.get_env(:omc, Omc.Usages)[:acc_min_usage_days],
        :day
      )

      # second usage
      sa2 = ServersFixtures.server_acc_fixture(%{server_id: server.id})
      ServersFixtures.activate_server_acc(server, sa2)
      assert {:error, :no_credit} = Usages.start_usage(ledger)
    end

    test "without available acc - failed_value: :no_server_acc_available" do
      server_fixture(@server_price)
      user = LedgersFixtures.unique_user_attrs()
      assert Usages.start_usage(user) == {:error, :no_server_acc_available}
    end

    test "success case should create server_acc_user & usage" do
      %{price_plan_id: price_plan_id} = server = server_fixture(@server_price)

      %{id: server_acc_id} =
        server_acc = ServersFixtures.server_acc_fixture(%{server_id: server.id})

      ServersFixtures.activate_server_acc(server, server_acc)
      %{user_id: user_id, user_type: user_type} = user = LedgersFixtures.unique_user_attrs()
      ledger_fixture(@initial_credit, user)

      {:ok,
       %{
         server_acc_user: %Omc.Servers.ServerAccUser{
           id: sau_id,
           user_type: ^user_type,
           user_id: ^user_id,
           server_acc_id: ^server_acc_id,
           allocated_at: sau_allocated_at,
           started_at: sau_started_at,
           ended_at: nil
         },
         usage: %Omc.Usages.Usage{
           server_acc_user_id: usage_sau_id,
           price_plan_id: ^price_plan_id,
           started_at: usage_started_at,
           ended_at: nil
         }
       }} = Usages.start_usage(user)

      assert TestUtils.happend_now_or_a_second_later(sau_allocated_at)
      assert TestUtils.happend_now_or_a_second_later(sau_started_at)
      assert TestUtils.happend_now_or_a_second_later(usage_started_at)
      assert sau_id == usage_sau_id
    end
  end

  describe "get_acc_usages_line_items/1" do
    setup :setup_a_usage_started

    test "just created usage - should have one usage_line_item with zero amount", %{
      usage: usage,
      ledger: ledger
    } do
      [
        %{
          usage_item_id: -1,
          started_at: started_at,
          ended_at: ended_at,
          amount: 0,
          currency: currency
        }
      ] = Usages.get_acc_usages_line_items(usage.server_acc_user_id)

      assert TestUtils.happend_now_or_a_second_later(started_at)
      assert TestUtils.happend_now_or_a_second_later(ended_at)
      assert ledger.currency == currency
    end

    test "only live usage line items", %{
      usage: usage,
      ledger: _ledger,
      server: _server
    } do
      # consuming some part of credit
      usage_duration_use_fixture(usage, 3, :day)
      Usages.update_usages()

      [%{usage_item_id: -1, started_at: started_at, ended_at: ended_at, amount: 1_000}] =
        Usages.get_acc_usages_line_items(usage.server_acc_user_id)

      assert TestUtils.happend_closely(started_at |> NaiveDateTime.add(3, :day), ended_at)
    end

    test "having persisted usages", %{
      usage: usage,
      ledger: ledger,
      server: _server
    } do
      # increasing user's credit; it should now have credit for 3.5 months
      ledger_tx_fixture(ledger, @initial_credit |> Money.multiply(6))

      # one month usage
      usage_duration_use_fixture(usage, 30, :day)
      Usages.update_usages()
      usage1 = Usages.get_active_usage_by_sau_id(usage.server_acc_user_id)
      assert usage1.id != usage.id
      assert usage1.server_acc_user_id == usage.server_acc_user_id

      # another one month usage
      usage_duration_use_fixture(usage1, 30, :day)
      Usages.update_usages()
      usage2 = Usages.get_active_usage_by_sau_id(usage.server_acc_user_id)

      # half month usage
      usage_duration_use_fixture(usage2, 15, :day)
      Usages.update_usages()

      [item1, item2, item3] = Usages.get_acc_usages_line_items(usage.server_acc_user_id)
      assert Money.new(item1.amount, item1.currency) |> Money.compare(@server_price) == 0
      assert item1.usage_item_id != -1
      assert Money.new(item2.amount, item2.currency) |> Money.compare(@server_price) == 0
      assert item2.usage_item_id != -1
      assert Money.new(item3.amount, item3.currency) |> Money.compare(@initial_credit) == 0
      assert item3.usage_item_id == -1
    end
  end

  describe "user_have_enough_credit_for_duration?/3" do
    setup :setup_a_usage_started

    test "no ledger" do
      refute %{user_type: :local, user_id: "12345"}
             |> Usages.user_have_enough_credit_for_duration?(1, :second)
    end

    test "single usage - full credit usage", %{ledger: ledger, usage: usage} do
      usage_duration_use_fixture(usage, 15, :day)
      Usages.update_usages()
      assert Ledgers.get_ledger(ledger) |> then(& &1.credit) == 0

      refute ledger |> Usages.user_have_enough_credit_for_duration?(1, :second)
    end

    test "single usage", %{ledger: ledger, usage: usage} do
      usage_duration_use_fixture(usage, 10, :day)
      Usages.update_usages()

      assert ledger |> Usages.user_have_enough_credit_for_duration?(5, :second)
      assert ledger |> Usages.user_have_enough_credit_for_duration?(4, :day)
      refute ledger |> Usages.user_have_enough_credit_for_duration?(6, :day)
    end
  end

  describe "send_credit_margin_duration_notifies/0 tests" do
    setup %{} do
      PubSub.subscribe(Omc.PubSub, "usages")
      setup_a_usage_started(%{})
    end

    test "do not reach the `margin` within next `duration`", %{
      usage: usage,
      ledger: %{user_id: user_id, user_type: user_type}
    } do
      usage_duration_use_fixture(usage, 14 * 24 - 2, :hour)
      Usages.send_credit_margin_duration_notifies(24, 1)

      refute_receive(
        {:usage_duration_margin_notify, %{user_id: ^user_id, user_type: ^user_type}, _message}
      )
    end

    test "reach the `margin` within next `duration`", %{
      usage: usage,
      ledger: %{user_id: user_id, user_type: user_type}
    } do
      usage_duration_use_fixture(usage, 14 * 24 - 1, :hour)
      Usages.send_credit_margin_duration_notifies(24, 1)

      assert_receive(
        {:usage_duration_margin_notify, %{user_id: ^user_id, user_type: ^user_type}}
      )
    end

    test "already reached the `margin`", %{
      usage: usage,
      ledger: %{user_id: user_id, user_type: user_type}
    } do
      usage_duration_use_fixture(usage, 14 * 24, :hour)
      Usages.send_credit_margin_duration_notifies(24, 1)
      refute_receive({:usage_duration_margin_notify, %{user_id: ^user_id, user_type: ^user_type}})
    end

    test "passed the `margin`", %{
      usage: usage,
      ledger: %{user_id: user_id, user_type: user_type}
    } do
      usage_duration_use_fixture(usage, 14 * 24 + 1, :hour)
      Usages.send_credit_margin_duration_notifies(24, 1)
      refute_receive({:usage_duration_margin_notify, %{user_id: ^user_id, user_type: ^user_type}})
    end

    test "all users get notified (tail call test)", %{
      server: server,
      usage: usage,
      ledger: %{user_id: user_id, user_type: user_type}
    } do
      # default user should get notified
      usage_duration_use_fixture(usage, 14 * 24 - 1, :hour)

      # another user and usages
      %{user_id: user_id1, user_type: user_type1} = ledger1 = ledger_fixture(@initial_credit)
      usage1 = usage_fixture(%{server: server, user_attrs: ledger1})
      usage_duration_use_fixture(usage1, 14 * 24 - 1, :hour)
      # another user and usages
      %{user_id: user_id2, user_type: user_type2} = ledger2 = ledger_fixture(@initial_credit)
      usage2 = usage_fixture(%{server: server, user_attrs: ledger2})
      usage_duration_use_fixture(usage2, 14 * 24 - 1, :hour)

      Usages.send_credit_margin_duration_notifies(24, 1, 1, 1)

      assert_receive({:usage_duration_margin_notify, %{user_id: ^user_id, user_type: ^user_type}})

      assert_receive(
        {:usage_duration_margin_notify, %{user_id: ^user_id1, user_type: ^user_type1}}
      )

      assert_receive(
        {:usage_duration_margin_notify, %{user_id: ^user_id2, user_type: ^user_type2}}
      )
    end
  end

  defp setup_a_usage_started(%{} = _context) do
    server = server_fixture(@server_price)
    ledger = ledger_fixture(@initial_credit)
    usage = usage_fixture(%{server: server, user_attrs: ledger})

    %{
      server: server,
      ledger: ledger,
      usage: usage
    }
  end

  defp assert_usages_equal(us1, us2) do
    assert TestUtils.happend_closely(us1.started_at, us2.started_at)
    assert TestUtils.happend_closely(us1.ended_at, us2.ended_at)
    assert us1.price_plan_id == us2.price_plan_id
    assert us1.server_acc_user_id == us2.server_acc_user_id
  end
end
