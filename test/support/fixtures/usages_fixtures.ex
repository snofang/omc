defmodule Omc.UsagesFixtures do
  import Omc.LedgersFixtures
  alias Omc.ServerAccUsers
  alias Omc.Usages
  alias Omc.ServersFixtures

  def server_fixture(server_price) do
    server =
      ServersFixtures.server_fixture(%{
        price: server_price |> Money.to_decimal() |> to_string()
      })

    server
  end

  def ledger_fixture(ledger_initial_credit) do
    user_attrs = %{user_type: :telegram, user_id: unique_user_id()}

    %{ledger: ledger, ledger_tx: _ledger_tx} =
      ledger_tx_fixture!(
        user_attrs
        |> Map.put(:money, ledger_initial_credit)
      )

    ledger
  end

  def usage_fixture(
        %{server: server, user_attrs: %{user_type: _, user_id: _} = user_attrs} = _attrs
      ) do
    server_acc = ServersFixtures.server_acc_fixture(%{server_id: server.id})
    ServersFixtures.activate_server_acc(server, server_acc)
    {:ok, sau} = ServerAccUsers.allocate_server_acc_user(user_attrs)
    %{usage: usage, server_acc_user: _sau} = Usages.start_usage!(sau)

    usage
  end

  def usage_used_fixture(%Usages.Usage{} = usage, duration) do
    {:ok, _usage} =
      usage
      |> Ecto.Changeset.change(started_at: Omc.Common.Utils.now(-1 * duration))
      |> Omc.Repo.update()

    usage
  end
end
