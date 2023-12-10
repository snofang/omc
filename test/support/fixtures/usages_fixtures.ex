defmodule Omc.UsagesFixtures do
  import Omc.LedgersFixtures
  alias Omc.PricePlans
  alias Omc.Usages
  alias Omc.ServersFixtures
  alias Omc.Servers.Server

  @spec server_fixture(Money.t()) :: %Server{}
  def server_fixture(server_price) do
    {:ok, price_plan} = PricePlans.create_price_plan(server_price)

    server =
      ServersFixtures.server_fixture(%{price_plan: price_plan, price_plan_id: price_plan.id})

    server
  end

  def ledger_fixture(ledger_initial_credit, user_attrs \\ nil) do
    user_attrs =
      if user_attrs, do: user_attrs, else: %{user_type: :telegram, user_id: unique_user_id()}

    %{ledger: ledger, ledger_tx: _ledger_tx} =
      ledger_tx_fixture!(
        user_attrs
        |> Map.put(:money, ledger_initial_credit)
      )

    ledger
  end

  def ledger_tx_fixture(%{user_id: user_id, user_type: user_type}, money) do
    %{ledger: ledger, ledger_tx: _ledger_tx} =
      ledger_tx_fixture!(
        %{user_id: user_id, user_type: user_type}
        |> Map.put(:money, money)
      )

    ledger
  end

  def usage_fixture(
        %{server: server, user_attrs: %{user_type: _, user_id: _} = user_attrs} = _attrs
      ) do
    server_acc = ServersFixtures.server_acc_fixture(%{server_id: server.id})
    ServersFixtures.activate_server_acc(server, server_acc)
    # {:ok, sau} = ServerAccUsers.allocate_server_acc_user(user_attrs)
    {:ok, %{usage: usage, server_acc_user: _sau}} = Usages.start_usage(user_attrs)

    usage
  end

  def usage_duration_use_fixture(%Usages.Usage{} = usage, duration, unit \\ :second) do
    {:ok, usage_updated} =
      usage
      |> Ecto.Changeset.change(started_at: Omc.Common.Utils.now(-1 * duration, unit))
      |> Omc.Repo.update()

    usage_updated
    |> Omc.Repo.preload([:price_plan])
  end
end
