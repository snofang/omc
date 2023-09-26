defmodule Omc.Ledgers do
  alias Omc.Repo
  alias Omc.Ledgers.{Ledger, LedgerTx}
  import Ecto.Query, warn: false

  def get_ledger(%{user_type: user_type, user_id: user_id} = attrs) do
    currency = attrs |> Map.get(:currency, default_currency())

    Ledger
    |> where(user_type: ^user_type, user_id: ^user_id, currency: ^currency)
    |> Repo.one()
  end

  defp create_ledger(attrs) do
    %Ledger{}
    |> Ledger.create_changeset(attrs)
    |> Repo.insert()
  end

  def get_ledger_txs(attrs) do
    attrs
    |> Map.put_new(:currency, default_currency())
    |> LedgerTx.ledger_tx_query()
    |> Repo.all()
  end

  def create_ledger_tx!(
        %{
          user_type: _user_type,
          user_id: _user_id,
          context: _context,
          amount: _amount,
          type: _credit_debit
        } = attrs
      ) do
    attrs = attrs |> Map.put_new(:currency, default_currency())

    Ecto.Multi.new()
    |> Ecto.Multi.run(:ledger, fn _repo, _changes ->
      case get_ledger(attrs) do
        nil -> create_ledger(attrs)
        ledger -> {:ok, ledger}
      end
    end)
    |> Ecto.Multi.run(:ledger_updated, fn _repo, %{ledger: ledger} ->
      Repo.update(ledger_update_changeset(ledger, attrs))
    end)
    |> Ecto.Multi.run(:ledger_tx, fn _repo, %{ledger: ledger} ->
      Repo.insert(LedgerTx.create_changeset(attrs |> Map.put(:ledger_id, ledger.id)))
    end)
    |> Repo.transaction()
    |> then(fn {:ok, changes} ->
      %{ledger: Map.get(changes, :ledger_updated), ledger_tx: Map.get(changes, :ledger_tx)}
    end)
  end

  defp ledger_update_changeset(ledger, %{type: type, amount: amount}) when amount > 0 do
    case type do
      :credit ->
        Ledger.update_changeset(ledger, %{credit: ledger.credit + amount})

      :debit ->
        Ledger.update_changeset(ledger, %{credit: ledger.credit - amount})
    end
  end

  def default_currency() do
    Application.get_env(:omc, :default_currency)
  end
end
