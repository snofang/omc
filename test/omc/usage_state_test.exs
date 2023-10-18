defmodule Omc.UsageStateTest do
  use ExUnit.Case, async: true
  alias Omc.Ledgers.Ledger
  alias Omc.Common.PricePlan
  alias Omc.Usages.{UsageState, Usage}
  alias Omc.Common.Utils

  setup %{} do
    price_plan = %PricePlan{
      duration: 30 * 24 * 60 * 60,
      prices: [Money.new(500, :USD), Money.new(450, :EUR)]
    }

    %{price_plan: price_plan}
  end

  describe "calc_duration_money/3 tests" do
    test "simple - multi currencies", %{price_plan: price_plan} do
      duration = 15 * 24 * 60 * 60

      assert UsageState.calc_duration_money(price_plan, :USD, duration)
             |> Money.compare(Money.new(250, :USD)) == 0

      assert UsageState.calc_duration_money(price_plan, :EUR, duration)
             |> Money.compare(Money.new(225, :EUR)) == 0
    end

    test "rounding behaviour", %{price_plan: price_plan} do
      duration = 10 * 24 * 60 * 60

      assert UsageState.calc_duration_money(price_plan, :USD, duration)
             |> Money.compare(Money.new(167, :USD)) == 0
    end

    test "current time usage should be zero", %{price_plan: price_plan} do
      assert UsageState.calc_duration_money(price_plan, :USD, 0)
             |> Money.compare(Money.new(0, :USD)) == 0
    end
  end

  describe "calc_money_duration/2 tests" do
    test "simple - multi currencies", %{price_plan: price_plan} do
      assert UsageState.calc_money_duration(price_plan, Money.new(250, :USD)) == 15 * 24 * 60 * 60
      assert UsageState.calc_money_duration(price_plan, Money.new(225, :EUR)) == 15 * 24 * 60 * 60
    end

    test "money more than price amount", %{price_plan: price_plan} do
      assert UsageState.calc_money_duration(price_plan, Money.new(750, :USD)) == 45 * 24 * 60 * 60
    end
  end

  describe "compute/1 simple one ledger, one usage, cases" do
    setup %{price_plan: price_plan} do
      ledgers = [
        %Ledger{id: 10, currency: :USD, credit: 500, updated_at: Utils.now(-1 * 24 * 60 * 60)}
      ]

      usages = [%Usage{id: 20, price_plan: price_plan, started_at: Utils.now(), usage_items: []}]
      usage_state = %UsageState{usages: usages, ledgers: ledgers}

      %{usage_state: usage_state}
    end

    test "no usage within @minimum_duration", %{
      usage_state: usage_state
    } do
      usage_state =
        usage_state
        |> put_in(
          [Access.key(:usages), Access.at(0), Access.key(:started_at)],
          Utils.now(-1 * UsageState.minimum_duration() + 1)
        )

      %UsageState{} = computed_usage_state = UsageState.compute(usage_state)
      assert computed_usage_state == usage_state
    end

    test "after @minimum_duration there should be usage", %{
      usage_state: usage_state,
      price_plan: price_plan
    } do
      usage_state =
        usage_state
        |> put_in(
          [Access.key(:usages), Access.at(0), Access.key(:started_at)],
          Utils.now(-1 * UsageState.minimum_duration())
        )

      %UsageState{} = computed_usage_state = UsageState.compute(usage_state)

      remaining_credit =
        Money.new(500, :USD)
        |> Money.subtract(
          UsageState.calc_duration_money(price_plan, :USD, UsageState.minimum_duration())
        )

      assert computed_usage_state.ledgers
             |> List.first()
             |> Ledger.credit_money()
             |> Money.compare(remaining_credit) == 0

      assert computed_usage_state.changesets |> length() == 1
    end

    test "all credit usage test", %{
      usage_state: usage_state
    } do
      # 30 days usage
      usage_state =
        usage_state
        |> put_in(
          [Access.key(:usages), Access.at(0), Access.key(:started_at)],
          Utils.now(-1 * 30 * 24 * 60 * 60)
        )

      %UsageState{} = computed_usage_state = UsageState.compute(usage_state)

      assert computed_usage_state.ledgers
             |> List.first()
             |> Ledger.credit_money()
             |> Money.compare(Money.new(0, :USD)) == 0
    end

    test "more than credit usage test", %{
      usage_state: usage_state
    } do
      # 45 days usage
      usage_state =
        usage_state
        |> put_in(
          [Access.key(:usages), Access.at(0), Access.key(:started_at)],
          Utils.now(-1 * 45 * 24 * 60 * 60)
        )

      %UsageState{} = computed_usage_state = UsageState.compute(usage_state)

      assert computed_usage_state.ledgers
             |> List.first()
             |> Ledger.credit_money()
             |> Money.compare(Money.new(-250, :USD)) == 0
    end
  end
end