defmodule Omc.Servers do
  @moduledoc """
  The Servers context.
  """

  import Ecto.Query, warn: false
  import Ecto.Query.API, only: [like: 2], warn: false
  alias Omc.Users
  alias Omc.Servers.ServerAcc
  alias Omc.Users.UserInfo
  alias Omc.Servers.ServerAccUser
  alias Omc.Usages
  alias Omc.ServerAccUsers
  alias Phoenix.PubSub
  alias Omc.Servers.{Server, ServerOps}
  alias Omc.Repo

  @doc """
  Returns the list of servers.

  ## Examples

      iex> list_servers()
      [%Server{}, ...]
  ## Options
    :id to list only one server based on its id.

  """
  def list_servers(filter_opts \\ []) do
    filter_opts = Keyword.validate!(filter_opts, id: nil)

    from(s in Server,
      left_join: in_use in subquery(server_accs_count_in_use_query()),
      on: in_use.server_id == s.id,
      left_join: available in subquery(server_accs_count_available_query()),
      on: available.server_id == s.id,
      select: %{
        s
        | available_acc_count: available.count,
          in_use_acc_count: in_use.count
      }
    )
    |> list_servers_query_filter_by_id(filter_opts[:id])
    |> Repo.all()
  end

  defp list_servers_query_filter_by_id(query, id) do
    case id do
      nil ->
        query

      _ ->
        query |> where(id: ^id)
    end
  end

  defp server_accs_count_in_use_query() do
    from(sa in ServerAcc,
      join: sau in ServerAccUser,
      on: sau.server_acc_id == sa.id,
      where: sa.status == :active and is_nil(sau.ended_at),
      group_by: sa.server_id,
      select: %{server_id: sa.server_id, count: count(sa.id)}
    )
  end

  defp server_accs_count_available_query() do
    from(sa in ServerAcc,
      left_join: sau in ServerAccUser,
      on: sau.server_acc_id == sa.id,
      where: sa.status == :active and is_nil(sau.id),
      group_by: sa.server_id,
      select: %{server_id: sa.server_id, count: count(sa.id)}
    )
  end

  @doc """
  Gets a single server.

  Raises `Ecto.NoResultsError` if the Server does not exist.

  ## Examples

      iex> get_server!(123)
      %Server{}

      iex> get_server!(456)
      ** (Ecto.NoResultsError)

  """
  def get_server!(id) do
    Server
    |> where(id: ^id)
    |> preload(:price_plan)
    |> Repo.one!()
  end

  @doc """
  Creates a server.

  ## Examples

      iex> create_server(%{field: value})
      {:ok, %Server{}}

      iex> create_server(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_server(attrs \\ %{}) do
    %Server{}
    |> Server.changeset(attrs, %{status: :active})
    |> Repo.insert()
  end

  @doc """
  Updates a server.

  ## Examples

      iex> update_server(server, %{field: new_value})
      {:ok, %Server{}}

      iex> update_server(server, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_server(%Server{} = server, attrs) do
    server
    |> Server.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a server.

  ## Examples

      iex> delete_server(server)
      {:ok, %Server{}}

      iex> delete_server(server)
      {:error, %Ecto.Changeset{}}

  """
  def delete_server(%Server{} = server) do
    server
    |> Server.changeset(%{})
    |> Repo.delete()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking server changes.

  ## Examples

      iex> change_server(server)
      %Ecto.Changeset{data: %Server{}}

  """
  def change_server(%Server{} = server, attrs \\ %{}) do
    Server.changeset(server, attrs)
  end

  alias Omc.Servers.ServerAcc

  @doc """
  Returns the list of server_accs.

  ## Examples

    iex> list_server_accs(bindings = %{id: _, server_id: _, status: _,  user_info: _})
      [%ServerAcc{}, ...]

  """
  @spec list_server_accs(map()) :: [%ServerAcc{}]
  def list_server_accs(bindings \\ %{}, page \\ 1, limit \\ 10) when page > 0 and limit > 0 do
    list_server_acc_query()
    |> server_accs_id(bindings |> Map.get(:id))
    |> server_accs_server_id(bindings |> Map.get(:server_id))
    |> server_accs_status(bindings |> Map.get(:status))
    |> Users.where_like_user_info(bindings |> Map.get(:user_info))
    |> limit(^limit)
    |> offset((^page - 1) * ^limit)
    |> order_by([acc], desc: acc.id)
    |> Repo.all()
  end

  defp list_server_acc_query() do
    from(sa in ServerAcc,
      left_join: sau in ServerAccUser,
      on: sau.server_acc_id == sa.id,
      left_join: ui in UserInfo,
      as: :user_info,
      on: ui.user_id == sau.user_id and ui.user_type == sau.user_type,
      select: %{
        sa
        | user_info:
            fragment(
              "concat('un:', ?, ', fn:', ?, ', ln:', ?)",
              ui.user_name,
              ui.first_name,
              ui.last_name
            )
      }
    )
  end

  defp server_accs_id(server_accs, id) when id == "" or id == nil,
    do: server_accs

  defp server_accs_id(server_accs, id),
    do: server_accs |> where([sa], sa.id <= ^id)

  defp server_accs_server_id(server_accs, server_id) when server_id == "" or server_id == nil,
    do: server_accs

  defp server_accs_server_id(server_accs, server_id),
    do: server_accs |> where(server_id: ^server_id)

  defp server_accs_status(server_acc, status) when status == "" or status == nil, do: server_acc
  defp server_accs_status(server_acc, status), do: server_acc |> where(status: ^status)

  @doc """
  Gets a single server_acc.

  Raises `Ecto.NoResultsError` if the Server acc does not exist.

  ## Examples

      iex> get_server_acc!(123)
      %ServerAcc{}

      iex> get_server_acc!(456)
      ** (Ecto.NoResultsError)

  """
  def get_server_acc!(id), do: Repo.get!(ServerAcc, id)

  @doc """
  Creates a server_acc.

  ## Examples

      iex> create_server_acc(%{field: value})
      {:ok, %ServerAcc{}}

      iex> create_server_acc(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_server_acc(attrs \\ %{}) do
    %ServerAcc{}
    |> ServerAcc.changeset(attrs, %{status: :active_pending})
    |> Repo.insert()
  end

  @doc """
  Creates multiple accs
  """
  def create_server_acc_batch(server_id, count) when server_id > 0 and count > 0 do
    1..count
    |> Enum.map(fn _i ->
      %{
        server_id: server_id
      }
    end)
    |> Enum.reduce([], fn acc, result ->
      case create_server_acc(acc) do
        {:ok, created_acc} -> [created_acc | result]
        _ -> result
      end
    end)
  end

  @doc """
  Updates a server_acc.

  ## Examples

      iex> update_server_acc(server_acc, %{field: new_value})
      {:ok, %ServerAcc{}}

      iex> update_server_acc(server_acc, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_server_acc(%ServerAcc{} = server_acc, attrs) do
    server_acc
    |> ServerAcc.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a server_acc.

  ## Examples

      iex> delete_server_acc(server_acc)
      {:ok, %ServerAcc{}}

      iex> delete_server_acc(server_acc)
      {:error, %Ecto.Changeset{}}
  """
  def delete_server_acc(%ServerAcc{} = server_acc) do
    server_acc
    |> ServerAcc.changeset(%{delete: true})
    |> Repo.delete()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking server_acc changes.

  ## Examples

      iex> change_server_acc(server_acc)
      %Ecto.Changeset{data: %ServerAcc{}}

  """
  def change_server_acc(%ServerAcc{} = server_acc, attrs \\ %{}) do
    ServerAcc.changeset(server_acc, attrs)
  end

  @doc """
  marks acc for deactivation
  it will be done/effective by some preodic user management ops 
  """
  def deactivate_acc(%ServerAcc{} = acc) do
    case acc
         |> ServerAcc.changeset(%{status: :deactive_pending})
         |> Repo.update() do
      {:ok, acc} ->
        PubSub.broadcast(Omc.PubSub, "server-tasks", {:sync_accs_server_task, acc.server_id})
        {:ok, acc}

      other ->
        other
    end
  end

  @doc """
  Updates waiting for changes accs(those having :active_pending or :deactive_pending status)
  based on current acc file existance
  """
  @spec sync_server_accs_status(:integer, non_neg_integer()) :: :ok
  def sync_server_accs_status(server_id, batch_size \\ 5) do
    list_server_accs(%{server_id: server_id, status: :active_pending}, 1, batch_size)
    |> Enum.each(fn acc ->
      update_server_acc(acc, ServerOps.acc_file_based_status_change(acc))
      |> broadcast_server_update()
    end)

    list_server_accs(%{server_id: server_id, status: :deactive_pending}, 1, batch_size)
    |> Enum.each(fn acc ->
      # update_server_acc(acc, ServerOps.acc_file_based_status_change(acc))
      try_deactivate_server_acc(acc)
      |> broadcast_server_update()
    end)
  end

  defp try_deactivate_server_acc(%ServerAcc{} = acc) do
    case ServerOps.acc_file_based_status_change(acc) do
      attrs = %{status: :deactive} ->
        case Ecto.Multi.new()
             |> Ecto.Multi.run(:acc, fn _repo, _changes ->
               update_server_acc(acc, attrs)
             end)
             |> Ecto.Multi.run(:usage, fn _repo, _changes ->
               end_acc_usage_if_exists(acc.id)
             end)
             |> Repo.transaction() do
          {:ok, %{acc: deactivated_acc}} -> {:ok, deactivated_acc}
          _ -> {:error, acc}
        end

      %{} ->
        {:ok, acc}
    end
  end

  defp end_acc_usage_if_exists(server_acc_id) do
    case ServerAccUsers.get_server_acc_user_in_use(server_acc_id) do
      nil ->
        {:ok, nil}

      sau ->
        # it is not possible to have sau started without having usage started.
        Usages.get_active_usage_by_sau_id(sau.id)
        |> Usages.end_usage()
    end
  end

  defp broadcast_server_update({result, acc}) do
    case result do
      :ok ->
        PubSub.broadcast(
          Omc.PubSub,
          "server_task_progress",
          {:progress, acc.server_id, "SUCCESS -> #{ServerAcc.name(acc)} -> #{acc.status}\n"}
        )

      :error ->
        PubSub.broadcast(
          Omc.PubSub,
          "server_task_progress",
          {:progress, acc.server_id, "FAILED -> #{ServerAcc.name(acc)} -> #{acc.data.status}\n"}
        )
    end
  end

  def get_default_server_price_plan(server_acc_id) do
    server_acc_id
    |> get_server_acc!()
    |> then(fn sa -> get_server!(sa.server_id) end)
    |> then(& &1.price_plan)
  end

  @doc """
  Creates accs in batch to fill up to server's `max_acc_count`.
  Note: This may fail if called concurrently on a single server.
  """
  def create_accs_up_to_max_count(server_id, batch_size \\ 5) do
    [%Server{} = server] = list_servers(id: server_id)

    current_active_pending_count =
      from(sa in ServerAcc,
        where: sa.server_id == ^server_id and sa.status == :active_pending,
        select: count(sa)
      )
      |> Repo.one!()

    ((server.max_acc_count || 0) - (server.available_acc_count || 0) -
       (server.in_use_acc_count || 0) -
       current_active_pending_count)
    |> min(batch_size)
    |> case do
      c when c > 0 ->
        create_server_acc_batch(server_id, c)

      _ ->
        nil
    end
  end
end
