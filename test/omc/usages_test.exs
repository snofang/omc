defmodule Omc.UsagesTest do
  use Omc.DataCase, async: true
  # alias Omc.Usages
  # alias Omc.Usages.{Usage, UsageState}
  # alias Omc.ServerAccUsers
  # alias Omc.Ledgers.Ledger
  # import Omc.ServersFixtures
  # import Omc.AccountsFixtures
  # import Omc.LedgersFixtures
  # @server_price Money.parse("30") |> then(fn {:ok, money} -> money end)
  # @server_price_duration 30 * 24 * 60 * 60
  # @initial_credit Money.parse("15") |> then(fn {:ok, money} -> money end)

  # defp setup_server_user_acc_started(%{} = _context) do
  #   user = user_fixture()
  #
  #   server =
  #     server_fixture(%{
  #       user_id: user.id,
  #       price: @server_price |> Money.to_decimal() |> to_string()
  #     })
  #
  #   server_acc = server_acc_fixture(%{server_id: server.id})
  #   activate_server_acc(server, server_acc)
  #   user_attrs = %{user_type: :telegram, user_id: unique_user_id()}
  #   {:ok, sau} = ServerAccUsers.allocate_server_acc_user(user_attrs)
  #
  #   %{ledger: ledger, ledger_tx: ledger_tx} =
  #     ledger_tx_fixture!(
  #       user_attrs
  #       |> Map.put(:money, @initial_credit)
  #     )
  #
  #   %{usage: usage, server_acc_user: sau} = Usages.start_usage!(sau)
  #   # {:ok, sau} = ServerAccUsers.start_server_acc_user(sau)
  #
  #   %{
  #     server: server,
  #     server_acc: server_acc,
  #     server_acc_user: sau,
  #     user_attrs: user_attrs,
  #     ledger: ledger,
  #     ledger_tx: ledger_tx,
  #     usage: usage
  #   }
  # end
  #
end
