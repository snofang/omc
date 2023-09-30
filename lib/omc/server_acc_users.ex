defmodule Omc.ServerAccUsers do
  alias Omc.Repo
  alias Omc.Servers.{Server, ServerAcc, ServerAccUser}
  import Ecto.Query, warn: false

  def allocate_a_server_acc_to_user(%{user_type: _, user_id: _} = user_attrs) do
    case first_available_server_and_acc() do
      nil ->
        {:error, :no_server_acc_available}

      attrs = %{server: _server, server_acc: _server_acc} ->
        case create_server_acc_user(attrs |> Map.merge(user_attrs)) do
          {:error, %{errors: [{:server_acc_id, _}]}} ->
            allocate_a_server_acc_to_user(user_attrs)

          other ->
            other
        end
    end
  end

  def create_server_acc_user(%{
        user_type: user_type,
        user_id: user_id,
        server: server,
        server_acc: server_acc
      }) do
    %{
      user_type: user_type,
      user_id: user_id,
      server_acc_id: server_acc.id,
      prices: server.prices
    }
    |> ServerAccUser.create_chageset()
    |> Repo.insert()
  end

  def first_available_server_and_acc() do
    query =
      from(server in Server,
        where: server.status == :active,
        join: server_acc in ServerAcc,
        on: server.id == server_acc.server_id,
        where: server_acc.status == :active,
        left_join: server_acc_user in ServerAccUser,
        on: server_acc.id == server_acc_user.server_acc_id,
        where: is_nil(server_acc_user.id),
        select: %{server: server, server_acc: server_acc},
        limit: 1
      )

    Repo.one(query)
  end
end
