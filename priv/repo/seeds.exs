# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Omc.Repo.insert!(%Omc.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.
Omc.Accounts.register_user(%{"email" => "admin@omc", "password" => "admin1234567"})

# predefined `PricePlans`
if(Omc.PricePlans.list_price_plans(name: "p2") == []) do
  Omc.PricePlans.create_price_plan([Money.new(199), Money.new(188, :EUR)], name: "p2")
end

if(Omc.PricePlans.list_price_plans(name: "p3") == []) do
  Omc.PricePlans.create_price_plan([Money.new(299), Money.new(288, :EUR)], name: "p3")
end

if(Omc.PricePlans.list_price_plans(name: "p4") == []) do
  Omc.PricePlans.create_price_plan([Money.new(399), Money.new(388, :EUR)], name: "p4")
end

if(Omc.PricePlans.list_price_plans(name: "p5") == []) do
  Omc.PricePlans.create_price_plan([Money.new(499), Money.new(488, :EUR)], name: "p5")
end
