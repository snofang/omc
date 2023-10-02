defmodule Omc.ServerAccUsers do
  use GenServer
  alias Omc.Servers
  alias Omc.Repo
  alias Omc.Servers.{Server, ServerAcc, ServerAccUser}
  import Ecto.Query, warn: false

  def start_link(_args) do
    GenServer.start_link(__MODULE__, Application.get_env(:omc, :acc_allocation_cleanup), name: __MODULE__)
  end

  @impl GenServer
  def init(acc_allocation_args) do
    Process.send_after(self(), :allocation_cleanup, acc_allocation_args[:schedule])
    {:ok, acc_allocation_args}
  end

  @impl GenServer
  def handle_info(:allocation_cleanup, acc_allocation_args) do
    cleanup_acc_allocations(acc_allocation_args[:timeout])
    Process.send_after(self(), :allocation_cleanup, acc_allocation_args[:schedule])
    {:noreply, acc_allocation_args}
  end

  # Allocates a `ServerAcc` to a user by creating a record of `ServerAccUser` in db and 
  # setting its `allocated_at` to the current `NaiveDateTime`.
  # This is triggered on any request for an acc for a given user. This is temporary 
  # and serves as mechanism to reserve an acc(before final activation which happens in `start` operation).
  # Actually a naive cart implementation it is.
  @doc false
  @spec allocate_new_server_acc_user(%{user_type: binary(), user_id: binary()}) ::
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
  @spec allocate_server_acc_user(%{user_type: binary(), user_id: binary()}) ::
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
        server: server,
        server_acc: server_acc
      }) do
    %{
      user_type: user_type,
      user_id: user_id,
      server_acc_id: server_acc.id,
      prices: server.prices,
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
  @spec get_server_acc_user_allocated(%{user_type: binary(), user_id: binary()}) ::
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
  Starts allocated `ServerAccUser` by filling its `started_at` to current `NaiveDateTime`
  This is the state in which acc should be available for use/download.
  """
  def start_server_acc_user(server_acc_user) do
    server_acc_user
    |> ServerAccUser.start_changeset()
    |> Repo.update()
  end

  @doc """
  Ends started `ServerAccUser` by setting its `ended_at` to current `NaiveDateTime` and also
  deactivating related `ServerAcc`.
  """
  @spec end_server_acc_user!(ServerAccUser.t()) :: %{
          server_acc: ServerAcc.t(),
          server_acc_user: ServerAccUser.t()
        }
  def end_server_acc_user!(server_acc_user) do
    {:ok,
     %{server_acc_updated: server_acc_updated, server_acc_user_updated: server_acc_user_updated}} =
      Ecto.Multi.new()
      # getting server_acc
      |> Ecto.Multi.run(:server_acc, fn _repo, _changes ->
        {:ok, Servers.get_server_acc!(server_acc_user.server_acc_id)}
      end)
      # marking acc for deactivation
      |> Ecto.Multi.run(:server_acc_updated, fn _repo, %{server_acc: server_acc} ->
        Servers.deactivate_acc(server_acc)
      end)
      # ending acc allocation
      |> Ecto.Multi.update(:server_acc_user_updated, ServerAccUser.end_changeset(server_acc_user))
      |> Repo.transaction()

    %{server_acc: server_acc_updated, server_acc_user: server_acc_user_updated}
  end

  @doc false
  def cleanup_acc_allocations(timeout) do
    query =
      from(sau in ServerAccUser,
        where: is_nil(sau.started_at) and sau.allocated_at < ago(^timeout, "second")
      )

    Repo.delete_all(query)
  end
end
