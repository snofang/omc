defmodule Omc.ServerAccUsers do
  alias Omc.Ledgers
  alias Omc.Servers
  alias Omc.Repo
  alias Omc.Servers.{Server, ServerAcc, ServerAccUser}
  import Ecto.Query, warn: false

  @doc """
  Returns all `ServerAccUser`s which are in use.
  """
  def get_server_acc_users_in_use(user = %{user_type: _, user_id: _}) do
    server_acc_users_in_use_query(user)
    |> Repo.all()
  end

  defp server_acc_users_in_use_query(%{user_type: user_type, user_id: user_id}) do
    from(sau in ServerAccUser,
      where:
        sau.user_type == ^user_type and
          sau.user_id == ^user_id and
          not is_nil(sau.started_at) and
          is_nil(sau.ended_at)
    )
  end

  @doc """
  Returns all in use server accs.
  """
  @spec list_active_accs(%{user_type: atom(), user_id: binary()}) :: [
          %{sa_id: integer(), sa_name: binary, sau_id: integer()}
        ]
  def list_active_accs(user = %{user_type: _, user_id: _}) do
    from(sau in server_acc_users_in_use_query(user),
      join: sa in ServerAcc,
      on: sa.id == sau.server_acc_id,
      select: %{sa_id: sa.id, sa_name: sa.name, sau_id: sau.id}
    )
    |> Repo.all()
  end

  # Allocates a `ServerAcc` to a user by creating a record of `ServerAccUser` in db and 
  # setting its `allocated_at` to the current `NaiveDateTime`.
  # This is triggered on any request for an acc for a given user. This is temporary 
  # and serves as mechanism to reserve an acc(before final activation which happens in `start` operation).
  # Actually a naive cart implementation it is.
  @doc false
  @spec allocate_new_server_acc_user(%{user_type: atom(), user_id: binary()}) ::
          {:ok, ServerAccUser.t()} | {:error, :no_server_acc_available} | {:error, any()}
  def allocate_new_server_acc_user(%{user_type: _, user_id: _} = user_attrs) do
    case first_available_server_and_acc() do
      nil ->
        {:error, :no_server_acc_available}

      attrs = %{server: _server, server_acc: _server_acc} ->
        case create_server_acc_user(attrs |> Map.merge(user_attrs)) do
          {:error, %{errors: [{:server_acc_id, {"has already been taken", _}}]}} ->
            allocate_new_server_acc_user(user_attrs)

          other ->
            other
        end
    end
  end

  @doc """
  Allocates a new `ServerAccUser` or if there exists one, renew its `allocated_at` field and 
  and rerurn the updated one.
  """
  @spec allocate_server_acc_user(%{user_type: atom(), user_id: binary()}) ::
          {:ok, ServerAccUser.t()} | {:error, :no_server_acc_available} | {:error, any()}
  def allocate_server_acc_user(%{user_type: _user_type, user_id: _user_id} = user_attrs) do
    existing_sau = get_server_acc_user_allocated(user_attrs)

    if existing_sau do
      update_allocation_server_acc_user(existing_sau)
    else
      allocate_new_server_acc_user(user_attrs)
    end
  end

  @doc false
  def create_server_acc_user(%{
        user_type: user_type,
        user_id: user_id,
        server_acc: server_acc
      }) do
    %{
      user_type: user_type,
      user_id: user_id,
      server_acc_id: server_acc.id,
      allocated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    }
    |> ServerAccUser.create_chageset()
    |> Repo.insert()
  end

  @doc false
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

  @doc false
  def update_allocation_server_acc_user(server_acc_user) do
    server_acc_user
    |> ServerAccUser.allocate_changeset()
    |> Repo.update()
  end

  @doc """
  Returns already allocated `ServerAccUser` if exists or nil.
  """
  @spec get_server_acc_user_allocated(%{user_type: atom(), user_id: binary()}) ::
          ServerAccUser.t()
  def get_server_acc_user_allocated(%{user_type: user_type, user_id: user_id}) do
    query =
      from(sau in ServerAccUser,
        where: sau.user_type == ^user_type and sau.user_id == ^user_id and is_nil(sau.started_at),
        join: sa in ServerAcc,
        on: sa.id == sau.server_acc_id,
        select: sau
      )

    Repo.one(query)
  end

  @doc """
  Starts allocated `ServerAccUser` by filling its `started_at` to current `NaiveDateTime`.
  """
  @spec start_server_acc_user(%ServerAccUser{}) ::
          {:ok, ServerAccUser.t()} | {:error, Ecto.Changest.t()} | {:error, :no_credit}
  def start_server_acc_user(%ServerAccUser{} = sau) do
    # TODO: to cosider required minimum credit for starting 
    Ledgers.get_ledgers(%{user_type: sau.user_type, user_id: sau.user_id})
    |> Enum.reduce(0, &(&1.credit + &2))
    |> case do
      credit_sum when credit_sum > 0 ->
        sau
        |> ServerAccUser.start_changeset()
        |> Repo.update()

      _ ->
        {:error, :no_credit}
    end
  end

  @doc """
  Ends started `ServerAccUser` by setting its `ended_at` to current `NaiveDateTime` and also
  deactivating related `ServerAcc`.
  returns on success a multi resutl {:ok, %{server_acc: _, server_acc_user: _}}
  """
  def end_server_acc_user(%ServerAccUser{} = sau) do
    server_acc = Servers.get_server_acc!(sau.server_acc_id)

    Ecto.Multi.new()
    # marking acc for deactivation
    |> Ecto.Multi.run(:server_acc, fn _repo, _changes ->
      Servers.deactivate_acc(server_acc)
    end)
    # ending acc allocation
    |> Ecto.Multi.update(:server_acc_user, ServerAccUser.end_changeset(sau))
    |> Repo.transaction()
  end

  @doc false
  def cleanup_acc_allocations(timeout) do
    query =
      from(sau in ServerAccUser,
        where: is_nil(sau.started_at) and sau.allocated_at < ago(^timeout, "second")
      )

    Repo.delete_all(query)
  end

  @spec get_server_acc_user(integer()) :: %ServerAccUser{}
  def get_server_acc_user(id) do
    ServerAccUser
    |> Repo.get(id)
  end
end
