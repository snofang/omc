defmodule Omc.UsagesTest do
  alias Omc.Ledgers
  use Omc.DataCase, async: true
  alias Omc.Usages
  alias Omc.ServerAccUsers
  alias Omc.Ledgers.Ledger
  alias Omc.Common.Utils
  import Omc.ServersFixtures
  import Omc.AccountsFixtures
  import Omc.LedgersFixtures

  @server_price Money.new(100_00)
  @initial_credit Money.new(50_00)

  describe "usage_state/1 tests" do
    setup :setup_usage_stareted

    test "5 days usage credit check", %{usage: usage, user_attrs: user_attrs} do
      {:ok, _usage} =
        usage
        |> change(started_at: Utils.now(-5 * 24 * 60 * 60))
        |> Repo.update()

      computed_money_credit =
        user_attrs
        |> Usages.get_usage_state()
        |> get_in([Access.key(:ledgers), Access.at(0)])
        |> Ledger.credit_money()

      assert @initial_credit
             |> Money.subtract((@server_price.amount * 5 / 30) |> round())
             |> Money.compare(computed_money_credit) == 0
    end
  end

  describe "usage_state_persist/1 tests" do
    setup :setup_usage_stareted

    test "5 days usage state should not cause any persistance", %{
      usage: usage,
      user_attrs: user_attrs
    } do
      {:ok, _usage} =
        usage
        |> change(started_at: Utils.now(-5 * 24 * 60 * 60))
        |> Repo.update()

      # compute usage_state
      usage_state = Usages.get_usage_state(user_attrs)
      assert usage_state.changesets |> length() == 1
      # trying to persis eligible changesets
      Usages.persist_usage_state!(usage_state)
      # recompute changeset
      usage_state = Usages.get_usage_state(user_attrs)
      assert usage_state.changesets |> length() == 1
    end

    test "20 days usage state should cause two persistance items", %{
      usage: usage,
      user_attrs: user_attrs
    } do
      {:ok, _usage} =
        usage
        |> change(started_at: Utils.now(-20 * 24 * 60 * 60))
        |> Repo.update()

      # compute usage_state
      usage_state = Usages.get_usage_state(user_attrs)
      assert usage_state.changesets |> length() == 2
      # trying to persis eligible changesets
      Usages.persist_usage_state!(usage_state)
      # recompute changeset
      usage_state = Usages.get_usage_state(user_attrs)
      assert usage_state.changesets |> length() == 0
      assert Ledgers.get_ledger(user_attrs) |> then(& &1.credit) < 0
    end
  end

  defp setup_usage_stareted(%{} = _context) do
    user = user_fixture()

    server =
      server_fixture(%{
        user_id: user.id,
        price: @server_price |> Money.to_decimal() |> to_string()
      })

    server_acc = server_acc_fixture(%{server_id: server.id})
    activate_server_acc(server, server_acc)
    user_attrs = %{user_type: :telegram, user_id: unique_user_id()}
    {:ok, sau} = ServerAccUsers.allocate_server_acc_user(user_attrs)

    %{ledger: ledger, ledger_tx: ledger_tx} =
      ledger_tx_fixture!(
        user_attrs
        |> Map.put(:money, @initial_credit)
      )

    %{usage: usage, server_acc_user: sau} = Usages.start_usage!(sau)

    %{
      server: server,
      server_acc: server_acc,
      server_acc_user: sau,
      user_attrs: user_attrs,
      ledger: ledger,
      ledger_tx: ledger_tx,
      usage: usage
    }
  end
end
