defmodule Omc.Usages do
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
  @spec get_usage_state(%{user_type: atom(), user_id: binary()}) :: UsageState.t()
  def get_usage_state(%{user_type: _user_type, user_id: _user_id} = attrs) do
    %UsageState{
      usages: list_active_usages(attrs),
      ledgers: Ledgers.get_ledgers(attrs)
    }
    |> UsageState.compute()
  end

  @doc """
  Persists those changesets of a computed `UserState` which are final.
  Final changesets are those which caused a ledger's credit non-positive.
  Returns same `UsageState` intact
  """
  def persist_usage_state!(%UsageState{} = usage_state) do
    usage_state.changesets
    |> Enum.filter(fn %{ledger_changeset: changeset} -> changeset.changes.credit <= 0 end)
    |> Enum.map(fn changeset -> {:ok, _} = persist_usage_state_changeset(changeset) end)

    usage_state
  end

  defp persist_usage_state_changeset(%{
         ledger_changeset: ledger_changeset,
         ledger_tx_changeset: ledger_tx_changeset,
         usage_item_changeset: usage_item_changeset
       }) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:usage_item, usage_item_changeset)
    |> Ecto.Multi.run(:ledger, fn _repo, %{usage_item: usage_item} ->
      # TODO: this is messy; Ledgers should expose a function to persist changesets.
      %{
        user_type: ledger_changeset.data.user_type,
        user_id: ledger_changeset.data.user_id,
        context: :usage,
        context_id: usage_item.id,
        money: Money.new(ledger_tx_changeset.changes.amount, ledger_changeset.data.currency),
        type: :debit
      }
      |> Ledgers.create_ledger_tx!()
      |> then(&{:ok, &1})
    end)
    |> Repo.transaction()
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
  Creates a new `Usage` `started_at` now and following on, it'll be possible to calculate `sau` usages.
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
