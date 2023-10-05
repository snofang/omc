defmodule Omc.UsagesTest do
  # alias Omc.Ledgers
  use Omc.DataCase, async: true
  # alias Omc.Ledgers.Ledger
  # alias Omc.ServerAccUsers
  import Omc.ServersFixtures
  import Omc.AccountsFixtures
  import Omc.LedgersFixtures

  setup %{} do
    user = user_fixture()
    server = server_fixture(%{user_id: user.id})
    server_acc = server_acc_fixture(%{server_id: server.id})
    activate_server_acc(server, server_acc)
    user_attrs = %{user_type: :telegram, user_id: unique_user_id()}
    %{server: server, server_acc: server_acc, user_attrs: user_attrs}
  end

  # describe "usage_state/1 tests" do
  #   test "single acc usage test", %{user_attrs: user_attrs} do
  #     {:ok, sau} = ServerAccUsers.allocate_server_acc_user(user_attrs) 
  #     Ledgers.create_ledger_tx!()
  #     
  #     
  #   end
  # end
end
