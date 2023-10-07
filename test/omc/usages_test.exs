defmodule Omc.UsagesTest do
  alias Omc.Usages
  use Omc.DataCase, async: true
  alias Omc.ServerAccUsers
  alias Omc.Ledgers.Ledger
  import Omc.ServersFixtures
  import Omc.AccountsFixtures
  import Omc.LedgersFixtures
  @server_price Money.parse("30") |> then(fn {:ok, money} -> money end)
  @initial_credit Money.parse("15") |> then(fn {:ok, money} -> money end)

  setup %{} do
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

    {:ok, sau} = ServerAccUsers.start_server_acc_user(sau)

    %{
      server: server,
      server_acc: server_acc,
      server_acc_user: sau,
      user_attrs: user_attrs,
      ledger: ledger,
      ledger_tx: ledger_tx
    }
  end

  describe "usage_state/1 tests" do
    test "no usage within @minimum_considerable_usasge_in_seconds", %{
      server_acc_user: sau,
      user_attrs: user_attrs,
      ledger: ledger
    } do
      %Usages.UsageState{} = usage_state = Usages.usage_state(user_attrs)
      assert usage_state.server_acc_user_changesets == []
      assert usage_state.ledger_tx_changesets == []
      assert usage_state.server_acc_user_create_changesets == []
      assert usage_state.server_acc_users == [sau]
      assert usage_state.ledgers == [ledger]
    end

    test "after @minimum_considerable_usasge_in_seconds there should be usage", %{
      server_acc_user: sau,
      user_attrs: user_attrs,
      ledger: ledger
    } do
      # marking one hour usage
      {:ok, sau} =
        sau
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
        |> Money.subtract(Usages.calc_usage(sau, ledger.currency))

      %Usages.UsageState{} = usage_state = Usages.usage_state(user_attrs)

      assert usage_state.ledgers
             |> List.first()
             |> Ledger.credit_money()
             |> Money.compare(remaining_credit) == 0
    end
  end
end
