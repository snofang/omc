defmodule Omc.Usages do
  @moduledoc """
  Collects all functionalities related to calculating user's acc usages by providing required
  changesets to:
    - update a `ledger`. 
    - adding coresponding `ledger_tx`
    - starting/ending `Usage`/`UsageItem`
  It is better to not persist any changeset if possible, and instead use
  calculated values (applying changeset in memory) as much as possible; Because most of the times 
  users wants to see their remaning credit using this module and somtimes on some periodic calls 
  system wants to see usage date for possible persistance/closure.
  """

  alias Omc.Servers
  alias Omc.Usages.UsageItem
  alias Omc.ServerAccUsers
  alias Omc.Servers.ServerAccUser
  alias Omc.Ledgers
  alias Omc.Usages.{Usage, UsageState}
  alias Omc.Repo
  import Ecto.Query

  @doc """
  Returns current usage state (without persisting anything) in terms of current computed last `UsageState`
  """
  @spec usage_state(%{user_type: atom(), user_id: binary()}) :: UsageState.t()
  def usage_state(%{user_type: _user_type, user_id: _user_id} = attrs) do
    %UsageState{
      usages: list_active_usages(attrs),
      ledgers: Ledgers.get_ledgers(attrs)
    }
    |> UsageState.compute()
  end

  # def restart_usage(%ServerAccUser{} = sau) do
  #   Ecto.Multi.new()
  #   |> Ecto.Multi.run(:server_acc_user_end, fn _repo, _changes ->
  #     ServerAccUsers.end_server_acc_user()
  #   end)
  #
  #   # |> Ecto.Multi.run(:server_acc_user_start, fn _repo, _changes ->)
  # end

  # TODO: Optimize via inner query to fetch only the last usage item
  defp list_active_usages(%{user_type: _, user_id: _} = attrs) do
    server_acc_users = ServerAccUsers.get_server_acc_users_in_use(attrs)

    usage_items = from(ui in UsageItem, order_by: [asc: ui.id])

    from(u in Usage,
      where:
        u.server_acc_user_id in ^(server_acc_users |> Enum.map(&Map.get(&1, :id))) and
          is_nil(u.ended_at),
      preload: [usage_items: ^usage_items]
    )
    |> Repo.all()
  end

  @doc """
  Creates new `Usage` to indicate usage start.
  From this on, it is possible to calculate duration or volume usage.
  """
  @spec start_usage!(%ServerAccUser{}) :: %{usage: %Usage{}, server_acc_user: %ServerAccUser{}}
  def start_usage!(%ServerAccUser{} = sau) do
    {:ok, %{sau_started: sau_started, usage_started: usage_started}} =
      Ecto.Multi.new()
      |> Ecto.Multi.run(:sau_started, fn _repo, _changes ->
        ServerAccUsers.start_server_acc_user(sau)
      end)
      |> Ecto.Multi.run(:usage_started, fn _repo, %{sau_started: sau_started} ->
        create_usage(sau_started)
      end)
      |> Repo.transaction()

    %{usage: usage_started |> Repo.preload(:usage_items), server_acc_user: sau_started}
  end

  defp create_usage(%ServerAccUser{} = sau) do
    %{
      server_acc_user_id: sau.id,
      started_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
      price_plan: Servers.get_default_server_price_plan(sau.server_acc_id)
    }
    |> Usage.create_changeset()
    |> Repo.insert()
  end
end
