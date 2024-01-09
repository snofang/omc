defmodule Omc.ServerAccUsers do
  alias Omc.PricePlans
  alias Omc.Ledgers
  alias Omc.Repo
  alias Omc.Servers.{Server, ServerAcc, ServerAccUser}
  import Ecto.Query, warn: false
  import Ecto.Query.API, only: [count: 1], warn: false

  @doc """
  Returns all accs which are in use for a given user.
  """
  @spec get_server_accs_in_use(%{user_type: atom(), user_id: binary()}) :: [
          %{
            s_id: non_neg_integer(),
            sa_id: non_neg_integer(),
            sau_id: non_neg_integer(),
            s_tag: binary()
          }
        ]
  def get_server_accs_in_use(%{user_type: user_type, user_id: user_id}) do
    from(
      sau in subquery(
        server_acc_users_in_use_query()
        |> where([sau], sau.user_type == ^user_type and sau.user_id == ^user_id)
      ),
      join: sa in ServerAcc,
      on: sa.id == sau.server_acc_id,
      join: s in Server,
      on: s.id == sa.server_id,
      select: %{s_id: s.id, sa_id: sa.id, sau_id: sau.id, s_tag: s.tag}
    )
    |> Repo.all()
  end

  @doc """
  Returns in use `ServerAccUser` associated with given `server_acc_id`
  """
  def get_server_acc_user_in_use(server_acc_id) do
    from(sau in server_acc_users_in_use_query(),
      where: sau.server_acc_id == ^server_acc_id
    )
    |> Repo.one()
  end

  defp server_acc_users_in_use_query() do
    from(sau in ServerAccUser,
      where:
        not is_nil(sau.started_at) and
          is_nil(sau.ended_at)
    )
  end

  # Allocates a `ServerAcc` for a user by creating a record of `ServerAccUser` in db and 
  # setting its `allocated_at` to the current `NaiveDateTime`.
  # This is triggered on any request for an acc for a given user. This is temporary 
  # and serves as mechanism to reserve an acc(before final activation which happens in `start` operation).
  # Actually a naive cart implementation it is.
  @doc false
  @spec allocate_new_server_acc_user(%{user_type: atom(), user_id: binary()}, opts :: Keyword.t()) ::
          {:ok, ServerAccUser.t()} | {:error, :no_server_acc_available} | {:error, any()}
  def allocate_new_server_acc_user(%{user_type: _, user_id: _} = user_attrs, opts \\ []) do
    case first_available_server_and_acc(opts) do
      nil ->
        {:error, :no_server_acc_available}

      attrs = %{server: _server, server_acc: _server_acc} ->
        case create_server_acc_user(attrs |> Map.merge(user_attrs)) do
          # TODO: this does not have test; better to use GenServer instead 
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

  @doc """
  Returns first available(unallocated, unused) `Server` and `ServerAcc` tuple. 

  ## Options
    * `:server_tag` 
    * `:price_plan_id`
  """
  @spec first_available_server_and_acc(options :: Keyword.t()) ::
          %{
            server: %Server{},
            server_acc: %ServerAcc{}
          }
          | nil
  def first_available_server_and_acc(args \\ []) do
    args = Keyword.validate!(args, server_tag: nil, price_plan_id: nil)

    available_server_acc_query()
    |> select([s, sa, sau], %{server: s, server_acc: sa})
    # server_tag
    |> then(fn q ->
      if args[:server_tag] do
        q |> where([s, sa, sau], s.tag == ^args[:server_tag])
      else
        q
      end
    end)
    # server_plan_id
    |> then(fn q ->
      if args[:price_plan_id] do
        q |> where([s, sa, sau], s.price_plan_id == ^args[:price_plan_id])
      else
        q
      end
    end)
    |> limit(1)
    |> Repo.one()
  end

  # TODO: to optimise this; currently being done via 2 queries 
  @spec list_server_tags_with_free_accs_count() :: [%{tag: binary(), count: integer()}]
  def list_server_tags_with_free_accs_count() do
    from([s, sa, sau] in available_server_acc_query(),
      group_by: [s.tag, s.price_plan_id],
      select: %{tag: s.tag, price_plan_id: s.price_plan_id, count: count(sa.id)}
    )
    |> Repo.all()
    |> Enum.map(&Map.put(&1, :price_plan, PricePlans.get_price_plan!(&1.price_plan_id)))
  end

  defp available_server_acc_query() do
    from(server in Server,
      where: server.status == :active,
      join: server_acc in ServerAcc,
      on: server.id == server_acc.server_id,
      where: server_acc.status == :active,
      left_join: server_acc_user in ServerAccUser,
      on: server_acc.id == server_acc_user.server_acc_id,
      where: is_nil(server_acc_user.id)
    )
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
  Ends started `ServerAccUser` by setting its `ended_at` to current `NaiveDateTime`. 
  """
  def end_server_acc_user(%ServerAccUser{} = sau) do
    ServerAccUser.end_changeset(sau)
    |> Repo.update()
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
