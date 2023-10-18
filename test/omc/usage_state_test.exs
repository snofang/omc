defmodule Omc.UsageStateTest do
  use ExUnit.Case, async: true
  alias Omc.Ledgers.Ledger
  alias Omc.Common.PricePlan
  alias Omc.Usages.{UsageState, Usage}
  alias Omc.Common.Utils
  @price_plan_duration 30 * 24 * 60 * 60
  @usd_price Money.new(500, :USD)
  @eur_price Money.new(450, :EUR)

  setup %{} do
    price_plan = %PricePlan{
      duration: @price_plan_duration,
      prices: [@usd_price, @eur_price]
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

  describe "compute/1, one ledger, one usage, cases" do
    setup %{price_plan: price_plan} do
      ledgers = [
        %Ledger{
          id: 10,
          currency: :USD,
          credit: 500,
          updated_at: Utils.now(-1 * 24 * 60 * 60)
        }
      ]

      usages = [%Usage{id: 20, price_plan: price_plan, started_at: Utils.now(), usage_items: []}]
      usage_state = %UsageState{usages: usages, ledgers: ledgers}

      %{usage_state: usage_state}
    end

    test "before @minimum_duration usage test", %{
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

    test "after @minimum_duration usage test", %{
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

    test "30 days usage test", %{
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

    test "45 days usage test", %{
      usage_state: usage_state
    } do
      usage_started_at = Utils.now(-45 * 24 * 60 * 60)
      # 45 days usage
      usage_state =
        usage_state
        |> put_in(
          [Access.key(:usages), Access.at(0), Access.key(:started_at)],
          usage_started_at
        )

      %UsageState{} = computed_usage_state = UsageState.compute(usage_state)

      assert computed_usage_state.ledgers
             |> List.first()
             |> Ledger.credit_money()
             |> Money.compare(Money.new(-250, :USD)) == 0

      usage_started_at_30days_after = usage_started_at |> NaiveDateTime.add(30 * 24 * 60 * 60)
      usage_started_at_45days_after = usage_started_at |> NaiveDateTime.add(45 * 24 * 60 * 60)

      assert [
               %{
                 ledger_changeset: %{
                   changes: %{credit: 0},
                   errors: [],
                   valid?: true
                 },
                 ledger_tx_changeset: %{
                   changes: %{
                     amount: 500,
                     context: :usage,
                     context_id: -1,
                     ledger_id: 10,
                     type: :debit
                   },
                   errors: [],
                   valid?: true
                 },
                 usage_item_changeset: %{
                   changes: %{
                     ended_at: ^usage_started_at_30days_after,
                     started_at: ^usage_started_at,
                     type: :duration,
                     usage_id: 20
                   },
                   errors: [],
                   valid?: true
                 }
               },
               %{
                 ledger_changeset: %{
                   changes: %{credit: -250},
                   errors: [],
                   valid?: true
                 },
                 ledger_tx_changeset: %{
                   changes: %{
                     amount: 250,
                     context: :usage,
                     context_id: -1,
                     ledger_id: 10,
                     type: :debit
                   },
                   errors: [],
                   valid?: true
                 },
                 usage_item_changeset: %{
                   action: nil,
                   changes: %{
                     ended_at: ^usage_started_at_45days_after,
                     started_at: ^usage_started_at_30days_after,
                     type: :duration,
                     usage_id: 20
                   },
                   errors: [],
                   valid?: true
                 }
               }
             ] = computed_usage_state.changesets
    end
  end
end
