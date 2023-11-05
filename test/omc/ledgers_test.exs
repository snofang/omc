defmodule Omc.LedgersTest do
  use Omc.DataCase, asyc: true
  alias Omc.Ledgers
  alias Omc.Ledgers.{Ledger, LedgerTx}
  alias Omc.Common.Utils
  import Omc.LedgersFixtures

  describe "create_ledger_tx/1" do
    setup %{} do
      ledger_tx_fixture!()
    end

    test "ledger itself is created by a tx" do
      attrs = valid_ledger_tx_attrubutes()
      assert nil == Ledgers.get_ledger(attrs)

      %{
        ledger: %Ledger{} = ledger,
        ledger_tx: %LedgerTx{} = _ledger_tx
      } = Ledgers.create_ledger_tx!(%{attrs | money: Money.new(200), type: :credit})

      fetched_ledger = Ledgers.get_ledger(attrs)
      assert fetched_ledger.user_id == attrs |> Map.get(:user_id)
      assert fetched_ledger.user_type == attrs |> Map.get(:user_type)
      assert fetched_ledger.currency == Utils.default_currency()
      assert fetched_ledger.credit == 200
      assert fetched_ledger == ledger
    end

    test "adding credit/debit tx should increase/decrease ledger's credit amount", %{
      ledger: ledger
    } do
      ledger_updated =
        valid_ledger_tx_attrubutes(%{
          user_id: ledger.user_id,
          type: :credit,
          money: Money.new(100)
        })
        |> Ledgers.create_ledger_tx!()
        |> then(fn changes -> Map.get(changes, :ledger) end)

      assert ledger_updated.credit == ledger.credit + 100

      ledger_updated =
        valid_ledger_tx_attrubutes(%{
          user_id: ledger.user_id,
          type: :credit,
          money: Money.new(100)
        })
        |> Ledgers.create_ledger_tx!()
        |> then(fn changes -> Map.get(changes, :ledger) end)

      assert ledger_updated.credit == ledger.credit + 200

      ledger_updated =
        valid_ledger_tx_attrubutes(%{user_id: ledger.user_id, type: :debit, money: Money.new(200)})
        |> Ledgers.create_ledger_tx!()
        |> then(fn changes -> Map.get(changes, :ledger) end)

      assert ledger_updated.credit == ledger.credit
    end

    test "ledgerTx with :payment context requires :context_id" do
      attrs = valid_ledger_tx_attrubutes()

      assert_raise(RuntimeError, "", fn ->
        try do
          Ledgers.create_ledger_tx!(%{
            attrs
            | type: :credit,
              context: :payment,
              context_id: nil
          })
        rescue
          _ -> raise ""
        end
      end)
    end

    test "ledgerTx with :payment context success flow" do
      attrs = valid_ledger_tx_attrubutes()

      %{ledger: ledger, ledger_tx: ledger_tx} =
        Ledgers.create_ledger_tx!(%{
          attrs
          | type: :credit,
            money: Money.new(123),
            context: :payment,
            context_id: 123
        })

      assert ledger.credit == 123
      assert ledger_tx.context == :payment
      assert ledger_tx.context_id == 123
    end
  end

  describe "get_ledger_txs/1" do
    setup %{} do
      ledger_tx_fixture!()
    end

    test "get_ledger_txs should returen all txs descending" do
      attrs = valid_ledger_tx_attrubutes()
      Ledgers.create_ledger_tx!(%{attrs | money: Money.new(600), type: :credit})
      Ledgers.create_ledger_tx!(%{attrs | money: Money.new(100), type: :credit})
      Ledgers.create_ledger_tx!(%{attrs | money: Money.new(50), type: :debit})
      Ledgers.create_ledger_tx!(%{attrs | money: Money.new(150), type: :debit})

      txs = Ledgers.get_ledger_txs(attrs)
      assert txs |> length() == 4
      assert %{amount: 150, type: :debit} = Enum.at(txs, 0)
      assert %{amount: 50, type: :debit} = Enum.at(txs, 1)
      assert %{amount: 100, type: :credit} = Enum.at(txs, 2)
      assert %{amount: 600, type: :credit} = Enum.at(txs, 3)
    end
  end
end
