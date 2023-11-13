defmodule Omc.Ledgers do
  alias Omc.Common.Utils
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
    get_ledger(%{user_type: user_type, user_id: user_id, currency: Utils.default_currency()})
  end

  defp create_ledger(attrs) do
    %Ledger{}
    |> Ledger.create_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns all users's txs in default/given currency.

  ## Examples
    Omc.Ledgers.get_ledger_txs(%{user_id: "123456", user_type: :telegram})
    [%LedgerTx{...}]
    
    Omc.Ledgers.get_ledger_txs(%{user_id: "123456", user_type: :telegram, currency: :USD})
    [%LedgerTx{...}]
  """
  @spec get_ledger_txs(map()) :: list(%LedgerTx{})
  def get_ledger_txs(attrs)

  def get_ledger_txs(%{user_type: user_type, user_id: _, currency: currency} = attrs)
      when is_atom(user_type) and is_atom(currency) do
    attrs
    |> Map.put(:currency, currency)
    |> LedgerTx.ledger_tx_query()
    |> Repo.all()
  end

  def get_ledger_txs(%{user_type: _, user_id: _} = attrs) do
    get_ledger_txs(attrs |> Map.put(:currency, Utils.default_currency()))
  end

  @doc """
  Creates a new `LedgerTx` and updates its related `Ledger` accordingly.
  """
  def create_ledger_tx!(attrs)

  @spec create_ledger_tx!(%{
          user_type: atom(),
          user_id: binary(),
          context: :manual | :payment | :usage,
          context_id: integer() | nil,
          money: Money.t(),
          type: :credit | :debit
        }) :: %{ledger: Ledger.t(), ledger_tx: LedgerTx.t()}
  def create_ledger_tx!(%{
        user_type: user_type,
        user_id: user_id,
        context: context,
        context_id: context_id,
        money: money,
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
          context_id: context_id,
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
          context_id: context_id,
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

  @spec create_ledger_tx!(%{
          user_type: atom(),
          user_id: binary(),
          context: :manual,
          money: Money.t(),
          type: :credit | :debit
        }) :: %{ledger: Ledger.t(), ledger_tx: LedgerTx.t()}
  def create_ledger_tx!(
        %{
          user_type: _user_type,
          user_id: _user_id,
          context: _context,
          money: _money,
          type: _type
        } = attrs
      ) do
    create_ledger_tx!(attrs |> Map.put(:context_id, nil))
  end

  @doc """
  Returns changesets required to insert a `LedgerTx` and update its `Ledger` accordingly.
  """
  def ledger_update_changeset(attrs)

  @spec ledger_update_changeset(%{
          ledger: Ledger.t(),
          context: :usage,
          context_id: integer(),
          amount: integer(),
          type: :debit
        }) :: %{
          ledger_changeset: Ecto.Changeset.t(),
          ledger_tx_changeset: Ecto.Changeset.t()
        }
  def ledger_update_changeset(
        %{
          ledger: _ledger,
          context: :usage,
          context_id: _,
          amount: _amount,
          type: :debit
        } = attrs
      ) do
    __ledger_update_changeset__(attrs)
  end

  @spec ledger_update_changeset(%{
          ledger: Ledger.t(),
          context: :payment,
          context_id: integer(),
          amount: integer(),
          type: :credit
        }) :: %{
          ledger_changeset: Ecto.Changeset.t(),
          ledger_tx_changeset: Ecto.Changeset.t()
        }
  def ledger_update_changeset(
        %{
          ledger: _ledger,
          context: :payment,
          context_id: _,
          amount: _amount,
          type: :credit
        } = attrs
      ) do
    __ledger_update_changeset__(attrs)
  end

  @spec ledger_update_changeset(%{
          ledger: Ledger.t(),
          context: :manual,
          amount: integer(),
          type: :credit | :debit
        }) :: %{
          ledger_changeset: Ecto.Changeset.t(),
          ledger_tx_changeset: Ecto.Changeset.t()
        }
  def ledger_update_changeset(
        %{
          ledger: _ledger,
          context: :manual,
          amount: _amount,
          type: _credit_debit
        } = attrs
      ) do
    __ledger_update_changeset__(attrs |> Map.put(:context_id, nil))
  end

  defp __ledger_update_changeset__(
         %{
           ledger: ledger
         } = attrs
       ) do
    %{
      ledger_changeset: Ledger.update_changeset(ledger, attrs),
      ledger_tx_changeset: LedgerTx.create_changeset(attrs |> Map.put(:ledger_id, ledger.id))
    }
  end

  # @spec get_ledger_tx_by_context(atom(), integer()) :: %LedgerTx{} | nil
  def get_ledger_tx_by_context(context, context_id)
      when is_atom(context) and is_integer(context_id) do
    from(tx in LedgerTx, where: tx.context == ^context and tx.context_id == ^context_id)
    |> Repo.one()
  end

  @spec list_ledgers(Keyword.t()) :: list(%Ledger{})
  def list_ledgers(args) do
    args =
      Keyword.validate!(args, page: 1, limit: 10, user_id: nil, user_type: nil, currency: nil)

    Ledger
    |> list_ledgers_where_user_type(args[:user_type])
    |> list_ledgers_where_user_id(args[:user_id])
    |> list_ledgers_where_currency(args[:currency])
    |> offset(^((args[:page] - 1) * args[:limit]))
    |> limit(^args[:limit])
    |> order_by(desc: :id)
    |> Repo.all()
  end

  defp list_ledgers_where_user_type(query, user_type) when user_type == nil, do: query

  defp list_ledgers_where_user_type(query, user_type),
    do: query |> where(user_type: ^user_type)

  defp list_ledgers_where_user_id(query, user_id) when user_id == nil, do: query

  defp list_ledgers_where_user_id(query, user_id),
    do: query |> where([pr], like(pr.user_id, ^"%#{user_id}%"))

  defp list_ledgers_where_currency(query, currency) when currency == nil, do: query

  defp list_ledgers_where_currency(query, currency),
    do: query |> where(currency: ^currency)

  def get_ledger!(id) do
    Ledger
    |> Repo.get(id)
  end

  def get_ledger_txs_by_ledger_id(ledger_id) do
    LedgerTx
    |> where(ledger_id: ^ledger_id)
    |> Repo.all()
  end

  # def create_sample_ledgers() do
  #   1..200
  #   |> Enum.each(fn _i ->
  #     user_id = Ecto.UUID.generate()
  #
  #     %{
  #       user_type: :local,
  #       user_id: user_id,
  #       context: :manual,
  #       context_id: 0xF00000 + System.unique_integer([:positive, :monotonic]),
  #       money: Money.new(100),
  #       type: :credit
  #     }
  #     |> create_ledger_tx!()
  #
  #     %{
  #       user_type: :local,
  #       user_id: user_id,
  #       context: :payment,
  #       context_id: 0xF00000 + System.unique_integer([:positive, :monotonic]),
  #       money: Money.new(100),
  #       type: :credit
  #     }
  #     |> create_ledger_tx!()
  #   end)
  # end
end
