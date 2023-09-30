defmodule Omc.LedgersTest do
  use Omc.DataCase, asyc: true
  alias Omc.Ledgers
  alias Omc.Ledgers.{Ledger, LedgerTx}
  import Omc.LedgersFixtures

  describe "create_ledger_tx/1" do
    setup %{} do
      ledger_tx_fixrute()
    end

    test "ledger itself is created by a tx" do
      attrs = valid_ledger_tx_attrubutes()
      assert nil == Ledgers.get_ledger(attrs)

      %{
        ledger: %Ledger{} = ledger,
        ledger_tx: %LedgerTx{} = _ledger_tx
      } = Ledgers.create_ledger_tx!(%{attrs | amount: 200, type: :credit})

      fetched_ledger = Ledgers.get_ledger(attrs)
      assert fetched_ledger.user_id == attrs |> Map.get(:user_id)
      assert fetched_ledger.user_type == attrs |> Map.get(:user_type)
      assert fetched_ledger.currency == Ledgers.default_currency()
      assert fetched_ledger.credit == 200
      assert fetched_ledger == ledger
    end

    test "adding credit/debit tx should increase/decrease ledger's credit amount", %{
      ledger: ledger
    } do
      ledger_updated =
        valid_ledger_tx_attrubutes(%{user_id: ledger.user_id, type: :credit, amount: 100})
        |> Ledgers.create_ledger_tx!()
        |> then(fn changes -> Map.get(changes, :ledger) end)

      assert ledger_updated.credit == ledger.credit + 100

      ledger_updated =
        valid_ledger_tx_attrubutes(%{user_id: ledger.user_id, type: :credit, amount: 100})
        |> Ledgers.create_ledger_tx!()
        |> then(fn changes -> Map.get(changes, :ledger) end)

      assert ledger_updated.credit == ledger.credit + 200

      ledger_updated =
        valid_ledger_tx_attrubutes(%{user_id: ledger.user_id, type: :debit, amount: 200})
        |> Ledgers.create_ledger_tx!()
        |> then(fn changes -> Map.get(changes, :ledger) end)

      assert ledger_updated.credit == ledger.credit
    end
  end

  describe "get_ledger_txs/1" do
    setup %{} do
      ledger_tx_fixrute()
    end

    test "get_ledger_txs should returen all txs descending" do
      attrs = valid_ledger_tx_attrubutes()
      Ledgers.create_ledger_tx!(%{attrs | amount: 600, type: :credit})
      Ledgers.create_ledger_tx!(%{attrs | amount: 100, type: :credit})
      Ledgers.create_ledger_tx!(%{attrs | amount: 50, type: :debit})
      Ledgers.create_ledger_tx!(%{attrs | amount: 150, type: :debit})

      txs = Ledgers.get_ledger_txs(attrs)
      assert txs |> length() == 4
      assert %{amount: 150, type: :debit} = Enum.at(txs, 0)
      assert %{amount: 50, type: :debit} = Enum.at(txs, 1)
      assert %{amount: 100, type: :credit} = Enum.at(txs, 2)
      assert %{amount: 600, type: :credit} = Enum.at(txs, 3)
    end
  end
end
