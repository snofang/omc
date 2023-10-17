defmodule Omc.UsagesTest do
  alias Omc.Common.PricePlan
  use Omc.DataCase, async: true
  alias Omc.Usages
  alias Omc.Usages.Usage
  alias Omc.ServerAccUsers
  alias Omc.Ledgers.Ledger
  import Omc.ServersFixtures
  import Omc.AccountsFixtures
  import Omc.LedgersFixtures
  @server_price Money.parse("30") |> then(fn {:ok, money} -> money end)
  @initial_credit Money.parse("15") |> then(fn {:ok, money} -> money end)

  describe "calc_duration_usage/2 tests" do
    test "simple - multi currencies" do
      usage = usage([Money.new(500, :USD), Money.new(450, :EUR)], -15)
      assert Usages.calc_duration_usage(usage, :USD) |> Money.compare(Money.new(250, :USD)) == 0
      assert Usages.calc_duration_usage(usage, :EUR) |> Money.compare(Money.new(225, :EUR)) == 0
    end

    test "rounding behaviour" do
      usage = usage([Money.new(100, :USD)], -10)

      assert Usages.calc_duration_usage(usage, :USD) |> Money.compare(Money.new(33, :USD)) == 0
    end

    test "current time usage should be zero" do
      usage = usage([Money.new(100, :USD)], 0)
      assert Usages.calc_duration_usage(usage, :USD) |> Money.compare(Money.new(0, :USD)) == 0
    end

    test "not happend time usage should be zero" do
      usage = usage([Money.new(100, :USD)], 10)
      assert Usages.calc_duration_usage(usage, :USD) |> Money.compare(Money.new(0, :USD)) == 0
    end

    defp usage(prices, start_days_offset) do
      %Usage{
        price_plan: %PricePlan{
          duration_days: 30,
          prices: prices
        },
        started_at:
          NaiveDateTime.utc_now()
          |> NaiveDateTime.truncate(:second)
          |> NaiveDateTime.add(start_days_offset, :day),
        usage_items: []
      }
    end
  end

  describe "usage_state/1 tests" do
    setup :setup_server_user_acc_started

    test "no usage within @minimum_considerable_usasge_in_seconds", %{
      user_attrs: user_attrs,
      ledger: ledger,
      usage: usage
    } do
      %Usages.UsageState{} = usage_state = Usages.usage_state(user_attrs)
      assert usage_state.usages == [usage]
      assert usage_state.ledgers == [ledger]
      assert usage_state.changesets == []
    end

    test "after @minimum_considerable_usasge_in_seconds there should be usage", %{
      user_attrs: user_attrs,
      ledger: ledger,
      usage: usage
    } do
      # marking one hour usage
      {:ok, usage} =
        usage
        |> change(%{
          started_at:
            NaiveDateTime.utc_now()
            |> NaiveDateTime.truncate(:second)
            |> NaiveDateTime.add(-1 * Usages.minimum_considerable_usasge_in_seconds(), :second)
        })
        |> Repo.update()

      # expected remaining credit
      remaining_credit =
        @initial_credit
        |> Money.subtract(Usages.calc_duration_usage(usage, ledger.currency))

      %Usages.UsageState{} = usage_state = Usages.usage_state(user_attrs) 

      assert usage_state.ledgers
             |> List.first()
             |> Ledger.credit_money()
             |> Money.compare(remaining_credit) == 0
    end
  end

  defp setup_server_user_acc_started(%{} = _context) do
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
    # {:ok, sau} = ServerAccUsers.start_server_acc_user(sau)

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
