defmodule Omc.ServerAccUserTest do
  use Omc.DataCase, async: false
  alias Omc.ServerAccUsers
  import Omc.ServersFixtures
  import Omc.AccountsFixtures
  import Omc.LedgersFixtures

  describe "allocate_server_acc_user tests" do
    setup %{} do
      user = user_fixture()
      server = server_fixture(%{user_id: user.id})
      server_acc = server_acc_fixture(%{server_id: server.id})
      activate_server_acc(server, server_acc)
      user_attrs = %{user_type: :telegram, user_id: unique_user_id()}
      %{server: server, server_acc: server_acc, user_attrs: user_attrs}
    end

    test "creates a server_acc_user record with started_at and ended_at not set", %{
      user_attrs: user_attrs,
      server_acc: server_acc,
      server: server
    } do
      {:ok, server_acc_user} = ServerAccUsers.allocate_a_server_acc_to_user(user_attrs)
      assert user_attrs.user_type == server_acc_user.user_type
      assert user_attrs.user_id == server_acc_user.user_id
      assert server_acc.id == server_acc_user.server_acc_id
      assert server_acc_user.prices == server.prices 
      refute server_acc_user.started_at
      refute server_acc_user.ended_at
    end

    test "if there is no more acc, returns {:error, :no_server_acc_available}", %{
      user_attrs: user_attrs
    } do
      {:ok, _} = ServerAccUsers.allocate_a_server_acc_to_user(user_attrs)

      assert {:error, :no_server_acc_available} =
               ServerAccUsers.allocate_a_server_acc_to_user(user_attrs)
    end
  end
end
