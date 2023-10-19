defmodule Omc.UsagesTest do
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
      usage_used_fixture(usage, 5 * 24 * 60 * 60)

      computed_money_credit =
        %{user_type: ledger.user_type, user_id: ledger.user_id}
        |> Usages.get_usage_state()
        |> get_in([Access.key(:ledgers), Access.at(0)])
        |> Ledger.credit_money()

      assert @initial_credit
             |> Money.subtract((@server_price.amount * 5 / 30) |> round())
             |> Money.compare(computed_money_credit) == 0
    end
  end

  describe "usage_state_persist/1 tests" do
    setup :setup_a_usage_started

    test "5 days usage state should not cause any persistance", %{
      usage: usage,
      ledger: ledger
    } do
      usage_used_fixture(usage, 5 * 24 * 60 * 60)

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
      usage_used_fixture(usage, 20 * 24 * 60 * 60)

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

    test "users who's usage closed should not be listed", %{server: _server, ledger: _ledger} do
      # TODO: implement this after usage closure functionality developed
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
      usage_used_fixture(usage, 15 * 24 * 60 * 60)
      # Another user, usages, one day consumption.
      ledger1 = ledger_fixture(@initial_credit)
      usage1 = usage_fixture(%{server: server, user_attrs: ledger1})
      usage_used_fixture(usage1, 1 * 24 * 60 * 60)

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
      usage_used_fixture(usage, 15 * 24 * 60 * 60)
      # another user and usages; fixing all credit consuption.
      ledger1 = ledger_fixture(@initial_credit)
      usage1 = usage_fixture(%{server: server, user_attrs: ledger1})
      usage_used_fixture(usage1, 15 * 24 * 60 * 60)
      # another user and usages; fixing all credit consuption.
      ledger2 = ledger_fixture(@initial_credit)
      usage2 = usage_fixture(%{server: server, user_attrs: ledger2})
      usage_used_fixture(usage2, 15 * 24 * 60 * 60)

      Usages.update_usage_states(1, 1)

      assert Ledgers.get_ledger(ledger) |> Map.get(:credit) == 0
      assert Ledgers.get_ledger(ledger1) |> Map.get(:credit) == 0
      assert Ledgers.get_ledger(ledger2) |> Map.get(:credit) == 0
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
