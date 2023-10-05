defmodule Omc.Ledgers do
  alias Omc.Repo
  alias Omc.Ledgers.{Ledger, LedgerTx}
  import Ecto.Query, warn: false

  @doc """
  Returns all ledgers of the specied user in any currency.
  """
  @spec get_ledgers(%{user_type: atom(), user_id: binary()}) :: [Ledger.t()]
  def get_ledgers(%{user_type: user_type, user_id: user_id}) do
    Ledger
    |> where(user_type: ^user_type, user_id: ^user_id)
    |> Repo.all()
  end

  @doc """
  Returns available ledger in default/given currency or nil.
  """
  def get_ledger(attrs)

  @spec get_ledger(%{user_type: atom(), user_id: binary(), currency: atom()}) ::
          Ledger.t() | nil
  def get_ledger(%{user_type: user_type, user_id: user_id, currency: currency}) do
    Ledger
    |> where(user_type: ^user_type, user_id: ^user_id, currency: ^currency)
    |> Repo.one()
  end

  @spec get_ledger(%{user_type: atom(), user_id: binary()}) :: Ledger.t() | nil
  def get_ledger(%{user_type: user_type, user_id: user_id}) do
    get_ledger(%{user_type: user_type, user_id: user_id, currency: default_currency()})
  end

  defp create_ledger(attrs) do
    %Ledger{}
    |> Ledger.create_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns all users's txs in default currency.
  """
  def get_ledger_txs(%{user_type: _, user_id: _} = attrs) do
    attrs
    |> Map.put(:currency, default_currency())
    |> LedgerTx.ledger_tx_query()
    |> Repo.all()
  end

  @doc """
  Creates a new `LedgerTx` and updates its related `Ledger` accordingly.
  """
  @spec create_ledger_tx!(%{
          user_type: binary(),
          user_id: binary(),
          context: atom(),
          money: Money.t(),
          type: atom()
        }) :: %{ledger: Ledger.t(), ledger_tx: LedgerTx.t()}
  def create_ledger_tx!(%{
        user_type: user_type,
        user_id: user_id,
        context: context,
        money: %Money{} = money,
        type: type
      }) do
    # creating ledger if not exists
    # TODO: to convert this multi to transaction.run in order to have only one changeset call
    Ecto.Multi.new()
    |> Ecto.Multi.run(:ledger, fn _repo, _changes ->
      case get_ledger(%{user_type: user_type, user_id: user_id, currency: money.currency}) do
        nil -> create_ledger(%{user_type: user_type, user_id: user_id, currency: money.currency})
        ledger -> {:ok, ledger}
      end
    end)
    # updating ledger
    |> Ecto.Multi.run(:ledger_updated, fn _repo, %{ledger: ledger} ->
      Repo.update(
        ledger_update_changeset(%{
          ledger: ledger,
          context: context,
          amount: money.amount,
          type: type
        })
        |> then(&Map.get(&1, :ledger_changeset))
      )
    end)
    # inserting ledger_tx
    |> Ecto.Multi.run(:ledger_tx, fn _repo, %{ledger: ledger} ->
      Repo.insert(
        ledger_update_changeset(%{
          ledger: ledger,
          context: context,
          amount: money.amount,
          type: type
        })
        |> then(&Map.get(&1, :ledger_tx_changeset))
      )
    end)
    |> Repo.transaction()
    |> then(fn {:ok, changes} ->
      %{ledger: Map.get(changes, :ledger_updated), ledger_tx: Map.get(changes, :ledger_tx)}
    end)
  end

  @doc """
  Returns changesets required to insert a `LedgerTx` and update its `Ledger` accordingly.
  """
  @spec ledger_update_changeset(%{
          ledger: Ledger.t(),
          context: atom(),
          amount: integer(),
          type: atom()
        }) :: %{
          ledger_changeset: Ecto.Changeset.t(),
          ledger_tx_changeset: Ecto.Changeset.t()
        }
  def ledger_update_changeset(attrs)

  def ledger_update_changeset(
        %{
          ledger: _ledger,
          context: :usage,
          amount: _amount,
          type: :debit
        } = attrs
      ) do
    __ledger_update_changeset__(attrs)
  end

  def ledger_update_changeset(
        %{
          ledger: _ledger,
          context: :payment,
          amount: _amount,
          type: :credit
        } = attrs
      ) do
    __ledger_update_changeset__(attrs)
  end

  def ledger_update_changeset(
        %{
          ledger: _ledger,
          context: :manual,
          amount: _amount,
          type: _credit_debit
        } = attrs
      ) do
    __ledger_update_changeset__(attrs)
  end

  defp __ledger_update_changeset__(
         %{
           ledger: ledger,
           context: _context,
           amount: _amount,
           type: _credit_debit
         } = attrs
       ) do
    %{
      ledger_changeset: Ledger.update_changeset(ledger, attrs),
      ledger_tx_changeset: LedgerTx.create_changeset(attrs |> Map.put(:ledger_id, ledger.id))
    }
  end

  def default_currency() do
    Application.get_env(:money, :default_currency)
  end
end
