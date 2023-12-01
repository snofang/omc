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
                prices: [%Money{amount: 12345, currency: :USD}]
              }} = PricePlans.create_price_plan(Money.new(12345))
    end

    test "privoding default options should be effective" do
      assert {:ok,
              %{
                name: "good price plan",
                duration: 12345,
                prices: [%Money{amount: 12345, currency: :USD}]
              }} =
               PricePlans.create_price_plan(Money.new(12345),
                 name: "good price plan",
                 duration: 12345
               )
    end

    test "should get error on nil price" do
      assert {:error, %{errors: [prices: {"price can not be nil", []}]}} =
               PricePlans.create_price_plan(nil)
    end
  end

  describe "list_price_plans/1" do
    test "default listing should list all price plans" do
      PricePlans.create_price_plan(Money.new(12), name: "pp1")
      PricePlans.create_price_plan(Money.new(12345), name: "pp2")
      PricePlans.create_price_plan(Money.new(12), name: "pp3")
      assert PricePlans.list_price_plans() |> length() == 3
    end

    test "list by name" do
      PricePlans.create_price_plan(Money.new(12), name: "pp1")
      PricePlans.create_price_plan(Money.new(12345), name: "pp2")
      PricePlans.create_price_plan(Money.new(12), name: "pp3")

      assert [
               %{
                 name: "pp2",
                 prices: [%Money{amount: 12345, currency: :USD}]
               }
             ] = PricePlans.list_price_plans(name: "pp2")
    end
  end
end
