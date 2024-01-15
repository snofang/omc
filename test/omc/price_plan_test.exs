defmodule Omc.PricePlanTest do
  use Omc.DataCase, async: true
  alias Omc.PricePlans

  describe "create_price_plan/1" do
    test "specifying just price, default options is duration: 30days and name: default" do
      duration_30_days = 30 * 24 * 60 * 60

      assert {:ok,
              %{
                name: "default",
                duration: ^duration_30_days,
                prices: [
                  %Money{amount: 12345, currency: :USD},
                  %Money{amount: 67890, currency: :EUR}
                ]
              }} = PricePlans.create_price_plan([Money.new(12345), Money.new(67890, :EUR)])
    end

    test "price plans should have all supported currencies" do
      assert {:error, %{errors: [prices: {"price plan should have all supported currencies", _}]}} =
               PricePlans.create_price_plan([Money.new(12345)])
    end

    test "providing default options should be effective" do
      assert {:ok,
              %{
                name: "good price plan",
                duration: 12345,
                prices: [
                  %Money{amount: 12345, currency: :USD},
                  %Money{amount: 67890, currency: :EUR}
                ]
              }} =
               PricePlans.create_price_plan([Money.new(12345), Money.new(67890, :EUR)],
                 name: "good price plan",
                 duration: 12345
               )
    end

    test "should get error on nil price" do
      assert {:error, %{errors: [prices: {"can't be blank", [{:validation, :required}]}]}} =
               PricePlans.create_price_plan(nil)
    end
  end

  describe "list_price_plans/1" do
    test "default listing should list all price plans" do
      PricePlans.create_price_plan([Money.new(12), Money.new(24, :EUR)], name: "pp1")
      PricePlans.create_price_plan([Money.new(12345), Money.new(67890, :EUR)], name: "pp2")
      PricePlans.create_price_plan([Money.new(12), Money.new(24, :EUR)], name: "pp3")
      assert PricePlans.list_price_plans() |> length() == 3
    end

    test "list by name" do
      PricePlans.create_price_plan([Money.new(12), Money.new(24, :EUR)], name: "pp1")
      PricePlans.create_price_plan([Money.new(12345), Money.new(67890, :EUR)], name: "pp2")
      PricePlans.create_price_plan([Money.new(12), Money.new(24, :EUR)], name: "pp3")

      assert [
               %{
                 name: "pp2",
                 prices: [
                   %Money{amount: 12345, currency: :USD},
                   %Money{amount: 67890, currency: :EUR}
                 ]
               }
             ] = PricePlans.list_price_plans(name: "pp2")
    end
  end
end
