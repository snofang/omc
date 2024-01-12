defmodule Omc.UsageStateTest do
  use ExUnit.Case, async: true
  alias Omc.TestUtils
  alias Omc.Ledgers.Ledger
  alias Omc.Servers.PricePlan
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

  describe "compute/1, one ledger, one usage" do
    setup %{price_plan: price_plan} do
      ledgers = [
        %Ledger{
          id: 10,
          currency: :USD,
          credit: 500,
          updated_at: Utils.now(-1, :day)
        }
      ]

      usages = [%Usage{id: 20, price_plan: price_plan, started_at: Utils.now(), usage_items: []}]
      usage_state = %UsageState{usages: usages, ledgers: ledgers}

      %{usage_state: usage_state}
    end

    test "zero duration usage", %{
      usage_state: usage_state
    } do
      assert usage_state == UsageState.compute(usage_state)
    end

    test "1 second usage - minimum to cause zero credit change", %{usage_state: usage_state} do
      computed_usage_state = UsageState.compute(usage_state, Utils.now(1, :second))

      assert computed_usage_state.ledgers
             |> List.first()
             |> Ledger.credit_money()
             |> Money.compare(Money.new(500, :USD)) == 0

      assert computed_usage_state.changesets |> length() == 1
    end

    test "10 days usage", %{usage_state: usage_state} do
      computed_usage_state = UsageState.compute(usage_state, Utils.now(10, :day))

      assert computed_usage_state.ledgers
             |> List.first()
             |> Ledger.credit_money()
             |> Money.compare(Money.new(333, :USD)) == 0

      assert computed_usage_state.changesets |> length() == 1
    end

    test "30 days usage", %{usage_state: usage_state} do
      computed_usage_state = UsageState.compute(usage_state, Utils.now(30, :day))

      assert computed_usage_state.ledgers
             |> List.first()
             |> Ledger.credit_money()
             |> Money.compare(Money.new(0, :USD)) == 0

      assert computed_usage_state.changesets |> length() == 1
    end

    test "45 days usage", %{
      usage_state: usage_state
    } do
      computed_usage_state = UsageState.compute(usage_state, Utils.now(45, :day))

      assert computed_usage_state.ledgers
             |> List.first()
             |> Ledger.credit_money()
             |> Money.compare(Money.new(-250, :USD)) == 0

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
                     ended_at: ended_at_30_days_later,
                     started_at: started_at_now,
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
                     ended_at: ended_at_45_days_later,
                     started_at: started_at_30_days_later,
                     type: :duration,
                     usage_id: 20
                   },
                   errors: [],
                   valid?: true
                 }
               }
             ] = computed_usage_state.changesets

      assert TestUtils.happend_closely(started_at_now, Utils.now(), 5)
      assert TestUtils.happend_closely(ended_at_30_days_later, Utils.now(30, :day), 5)
      assert TestUtils.happend_closely(started_at_30_days_later, Utils.now(30, :day), 5)
      assert TestUtils.happend_closely(ended_at_45_days_later, Utils.now(45, :day), 5)
    end

    test "multiple compute calls on same usage_state should be equal", %{usage_state: usage_state} do
      us1 =
        usage_state
        |> UsageState.compute(Utils.now(35, :day))

      us2 =
        usage_state
        |> UsageState.compute(Utils.now(35, :day))
        |> UsageState.compute(Utils.now(35, :day))

      us3 =
        usage_state
        |> UsageState.compute(Utils.now(35, :day))
        |> UsageState.compute(Utils.now(35, :day))
        |> UsageState.compute(Utils.now(35, :day))

      assert us1 == us2
      assert us2 == us3
    end

    test "multiple compute calls on increasing duration should be accomulative", %{
      usage_state: usage_state
    } do
      us =
        usage_state
        |> UsageState.compute(Utils.now(15, :day))
        |> UsageState.compute(Utils.now(30, :day))
        |> UsageState.compute(Utils.now(45, :day))

      assert us.ledgers |> List.first() |> then(& &1.credit) == -250
      assert us.changesets |> length() == 3
    end
  end

  describe "compute/1, one ledger, multi usages" do
    setup %{price_plan: price_plan} do
      ledgers = [
        %Ledger{
          id: 10,
          currency: :USD,
          credit: 500,
          updated_at: Utils.now(-1, :day)
        }
      ]

      usages = [
        %Usage{id: 20, price_plan: price_plan, started_at: Utils.now(), usage_items: []},
        %Usage{id: 40, price_plan: price_plan, started_at: Utils.now(), usage_items: []}
      ]

      usage_state = %UsageState{usages: usages, ledgers: ledgers}
      %{usage_state: usage_state}
    end

    test "zero duration usage", %{usage_state: usage_state} do
      assert usage_state == UsageState.compute(usage_state)
    end

    test "1 second usage - minimum to cause zero credit change", %{usage_state: usage_state} do
      computed_usage_state = UsageState.compute(usage_state, Utils.now(1, :second))

      assert computed_usage_state.ledgers
             |> List.first()
             |> Ledger.credit_money()
             |> Money.compare(Money.new(500, :USD)) == 0

      assert computed_usage_state.changesets |> length() == 2
    end

    test "10 days usage", %{usage_state: usage_state} do
      computed_usage_state = UsageState.compute(usage_state, Utils.now(10, :day))

      assert computed_usage_state.ledgers
             |> List.first()
             |> Ledger.credit_money()
             |> Money.compare(Money.new(166, :USD)) == 0

      assert computed_usage_state.changesets |> length() == 2
    end

    test "30 days usage", %{usage_state: usage_state} do
      computed_usage_state = UsageState.compute(usage_state, Utils.now(30, :day))

      assert computed_usage_state.ledgers
             |> List.first()
             |> Ledger.credit_money()
             |> Money.compare(Money.new(-500, :USD)) == 0

      assert computed_usage_state.changesets |> length() == 2
    end
  end

  describe "compute/1, multi ledger, one usage" do
    setup %{price_plan: price_plan} do
      ledgers = [
        %Ledger{
          id: 10,
          currency: :USD,
          credit: 500,
          updated_at: Utils.now()
        },
        %Ledger{
          id: 20,
          currency: :EUR,
          credit: 450,
          updated_at: Utils.now(-1, :day)
        }
      ]

      usages = [%Usage{id: 30, price_plan: price_plan, started_at: Utils.now(), usage_items: []}]
      usage_state = %UsageState{usages: usages, ledgers: ledgers}

      %{usage_state: usage_state}
    end

    test "older credit should be used first", %{
      usage_state: usage_state
    } do
      assert %{currency: :EUR, credit: 0} =
               usage_state
               |> UsageState.compute(Utils.now(30, :day))
               |> then(&get_in(&1, [Access.key(:ledgers), Access.at(1)]))
    end

    test "both credit usages in order of updated_at date", %{
      usage_state: usage_state
    } do
      assert %{currency: :EUR, credit: 0} =
               usage_state
               |> UsageState.compute(Utils.now(45, :day))
               |> then(&get_in(&1, [Access.key(:ledgers), Access.at(1)]))

      assert %{currency: :USD, credit: 250} =
               usage_state
               |> UsageState.compute(Utils.now(45, :day))
               |> then(&get_in(&1, [Access.key(:ledgers), Access.at(0)]))
    end

    test "debit happens on most recently used credit", %{
      usage_state: usage_state
    } do
      assert [%{currency: :USD, credit: -250}, %{currency: :EUR, credit: 0}] =
               usage_state
               |> UsageState.compute(Utils.now(75, :day))
               |> then(& &1.ledgers)
    end
  end

  describe "changesets_of_ledger/1" do
    setup %{price_plan: price_plan} do
      ledgers = [
        %Ledger{
          id: 10,
          currency: :USD,
          credit: 500,
          updated_at: Utils.now(-1, :day)
        }
      ]

      usages = [%Usage{id: 20, price_plan: price_plan, started_at: Utils.now(), usage_items: []}]

      usage_state = %UsageState{usages: usages, ledgers: ledgers}
      %{usage_state: usage_state}
    end

    test "all changesets have ledger's change", %{usage_state: usage_state} do
      # this is a 30 days usage + 5 days usage
      assert usage_state
             |> UsageState.compute(Utils.now(35, :day))
             |> UsageState.changesets_of_ledger(%{id: 10})
             |> Enum.count() == 2
    end

    test "no ledger change changeset", %{usage_state: usage_state} do
      # this is a 30 days usage + 1 second usage
      assert usage_state
             |> UsageState.compute(
               Utils.now(30, :day)
               |> NaiveDateTime.add(1, :second)
             )
             |> UsageState.changesets_of_ledger(%{id: 10})
             |> Enum.count() == 1
    end
  end
end
