defmodule Omc.UsagesTest do
  alias Omc.Servers
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
        |> Usages.get_usage_state()
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

      usage_state = Usages.get_usage_state(ledger)
      assert get_in(usage_state.ledgers, [Access.at(0), Access.key(:credit)]) == 0
    end
  end

  describe "usage_state_persist/1 tests" do
    setup :setup_a_usage_started

    test "5 days usage state should not cause any persistance", %{
      usage: usage,
      ledger: ledger
    } do
      usage_duration_use_fixture(usage, 5, :day)

      # compute usage_state
      usage_state = Usages.get_usage_state(ledger)
      assert usage_state.changesets |> length() == 1
      # trying to persis eligible changesets
      Usages.persist_usage_state!(usage_state)
      # recompute changeset
      usage_state = Usages.get_usage_state(ledger)
      assert usage_state.changesets |> length() == 1
    end

    test "20 days usage state should cause two persistance items", %{
      usage: usage,
      ledger: ledger
    } do
      usage_duration_use_fixture(usage, 20, :day)

      # compute usage_state
      usage_state = Usages.get_usage_state(ledger)
      assert usage_state.changesets |> length() == 2
      # trying to persis eligible changesets
      Usages.persist_usage_state!(usage_state)
      # recompute changeset
      usage_state = Usages.get_usage_state(ledger)
      assert usage_state.changesets |> length() == 0
      assert Ledgers.get_ledger(ledger) |> then(& &1.credit) < 0
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
      usage_state = Usages.get_usage_state(ledger)
      assert usage_state.changesets |> length() == 4

      # persisting
      Usages.persist_usage_state!(usage_state)

      # recompute changeset
      usage_state = Usages.get_usage_state(ledger)
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
      usage_ended =
        usage
        |> usage_duration_use_fixture(1, :day)
        |> Usages.end_usage!()

      assert usage_ended.ended_at |> TestUtils.happend_now_or_a_second_later()

      # usage state
      usage_state = Usages.get_usage_state(Ledger.user_attrs(ledger))
      assert usage_state.ledgers |> List.first() |> Map.get(:credit) < @initial_credit.amount
      assert usage_state.usages == []
      assert usage_state.changesets == []

      # server_user_acc
      sau = ServerAccUsers.get_server_acc_user(usage.server_acc_user_id)
      assert TestUtils.happend_now_or_a_second_later(sau.ended_at)

      # server_acc
      acc = Servers.get_server_acc!(sau.server_acc_id)
      assert acc.status == :deactive_pending
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
      Usages.end_usage!(usage1)

      # usage state
      usage_state = Usages.get_usage_state(Ledger.user_attrs(ledger))
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

    test "a usage with no credit should ended", %{usage: usage, ledger: ledger} do
      usage
      |> usage_duration_use_fixture(15, :day)

      Usages.update_usage_states()
      Usages.end_usages_with_no_credit()

      usage_state = Usages.get_usage_state(ledger)
      assert usage_state.usages == []
      assert get_in(usage_state.ledgers, [Access.at(0), Access.key(:credit)]) == 0
    end

    test "all no credit usages are considered (tail call test)", %{
      server: server,
      usage: usage,
      ledger: ledger
    } do
      # default usage, all credit consumption
      usage_duration_use_fixture(usage, 15, :day)

      # another user and usages; fixing more than credit consumption.
      ledger1 = ledger_fixture(@initial_credit)

      usage_fixture(%{server: server, user_attrs: ledger1})
      |> usage_duration_use_fixture(20, :day)

      # another user and usages; fixing all credit consuption.
      ledger2 = ledger_fixture(@initial_credit)

      usage_fixture(%{server: server, user_attrs: ledger2})
      |> usage_duration_use_fixture(5, :day)

      usage_fixture(%{server: server, user_attrs: ledger2})
      |> usage_duration_use_fixture(7, :day)

      usage_fixture(%{server: server, user_attrs: ledger2})
      |> usage_duration_use_fixture(6, :day)

      Usages.update_usage_states()
      Usages.end_usages_with_no_credit()

      assert get_in(Usages.get_usage_state(ledger), [Access.key(:usages)]) == []
      assert get_in(Usages.get_usage_state(ledger1), [Access.key(:usages)]) == []
      assert get_in(Usages.get_usage_state(ledger2), [Access.key(:usages)]) == []
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
      ledger1 = ledger_fixture(@initial_credit)

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

      usage_state = Usages.get_usage_state(ledger)

      # ledgers credit updated
      assert usage_state.ledgers
             |> List.first()
             |> (& &1.credit).() < @initial_credit.amount

      # same usage result from ending as the one got from usage_state
      assert new_usage |> Map.put(:usage_items, []) == usage_state.usages |> List.first()

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
      assert get_in(Usages.get_usage_state(ledger), [
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
      usage_duration_use_fixture(usage, 30, :day)

      # another expired usage
      usage_fixture(%{server: server, user_attrs: ledger})
      |> usage_duration_use_fixture(32, :day)

      # another expired usage
      usage_fixture(%{server: server, user_attrs: ledger})
      |> usage_duration_use_fixture(30, :day)

      Usages.renew_usages_expired(1, 1)

      # there should exist a usage strted now
      assert Usages.get_usage_state(ledger)
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
      ledger: ledger,
      server: server
    } do
      # making default one as a candidate of close no-credit
      usage_duration_use_fixture(usage, 15, :day)

      # setting up another user; more than 30 days credit, renew candidate
      ledger1 = ledger_fixture(@initial_credit |> Money.multiply(3))

      renew_usage =
        usage_fixture(%{server: server, user_attrs: ledger1})
        |> usage_duration_use_fixture(30, :day)

      no_change_usage =
        usage_fixture(%{server: server, user_attrs: ledger1})
        |> usage_duration_use_fixture(5, :day)

      Usages.update_usages()

      assert Usages.get_usage_state(ledger)
             |> then(& &1.usages)
             |> length() == 0

      usage_state1 = Usages.get_usage_state(ledger1)

      assert get_in(usage_state1.usages, [Access.at(0)]) |> Map.replace(:usage_items, []) ==
               no_change_usage

      assert get_in(usage_state1.usages, [Access.at(1), Access.key(:started_at)])
             |> TestUtils.happend_now_or_a_second_later()

      assert get_in(usage_state1.usages, [Access.at(1), Access.key(:server_acc_user_id)]) ==
               renew_usage.server_acc_user_id
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
end
