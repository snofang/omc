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
      attrs = %{
        user_type: :telegram,
        user_id: ledger.user_id,
        context: :manual,
        money: Money.new(100),
        type: :credit
      }

      ledger_updated =
        Ledgers.create_ledger_tx!(attrs)
        |> then(fn changes -> Map.get(changes, :ledger) end)

      assert ledger_updated.credit == ledger.credit + 100

      ledger_updated =
        Ledgers.create_ledger_tx!(attrs)
        |> then(fn changes -> Map.get(changes, :ledger) end)

      assert ledger_updated.credit == ledger.credit + 200

      ledger_updated =
        attrs
        |> Map.put(:money, Money.new(200))
        |> Map.put(:type, :debit)
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
        Ledgers.create_ledger_tx!(
          attrs
          |> Map.merge(%{
            type: :credit,
            money: Money.new(123),
            context: :payment,
            context_id: 123,
            context_ref: "additional_external_ref"
          })
        )

      assert ledger.credit == 123
      assert ledger_tx.context == :payment
      assert ledger_tx.context_id == 123
      assert ledger_tx.context_ref == "additional_external_ref"
    end

    test "ledgerTx with :usage context requires :context_id" do
      assert_raise(RuntimeError, "", fn ->
        try do
          Ledgers.create_ledger_tx!(%{
            user_type: :telegram,
            user_id: unique_user_id(),
            context: :usage,
            money: Money.new(100)
          })
        rescue
          _ -> raise ""
        end
      end)
    end

    test "ledgerTx with :usage context success flow" do
      %{ledger: ledger, ledger_tx: ledger_tx} =
        Ledgers.create_ledger_tx!(%{
          user_type: :telegram,
          user_id: unique_user_id(),
          context: :usage,
          context_id: 123,
          money: Money.new(100)
        })

      assert ledger.credit == -100
      assert ledger_tx.context == :usage
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

  describe "list_ledgers/1" do
    test "limit, pagination, and order" do
      %{ledger: %{id: id1}} = ledger_tx_fixture!()
      %{ledger: %{id: id2}} = ledger_tx_fixture!()
      %{ledger: %{id: id3}} = ledger_tx_fixture!()

      assert [%{id: ^id3}] = Ledgers.list_ledgers(page: 1, limit: 1)
      assert [%{id: ^id2}] = Ledgers.list_ledgers(page: 2, limit: 1)
      assert [%{id: ^id1}] = Ledgers.list_ledgers(page: 3, limit: 1)
    end

    test "user_type filter" do
      %{ledger: %{id: id1}} = ledger_tx_fixture!(%{user_type: :local})
      %{ledger: %{id: _id2}} = ledger_tx_fixture!(%{user_type: :telegram})

      assert [%{id: ^id1}] = Ledgers.list_ledgers(user_type: :local)
    end

    test "user_id filter" do
      %{ledger: %{id: id1}} = ledger_tx_fixture!(%{user_id: "12345"})
      %{ledger: %{id: _id2}} = ledger_tx_fixture!(%{user_id: "67890"})

      assert [%{id: ^id1}] = Ledgers.list_ledgers(user_id: "234")
    end

    test "currency filter" do
      %{ledger: %{id: _id1}} = ledger_tx_fixture!(%{money: Money.new(100, :USD)})
      %{ledger: %{id: id2}} = ledger_tx_fixture!(%{money: Money.new(100, :EUR)})
      %{ledger: %{id: _id3}} = ledger_tx_fixture!(%{money: Money.new(100, :USD)})

      assert [%{id: ^id2}] = Ledgers.list_ledgers(currency: :EUR)
    end
  end
end
