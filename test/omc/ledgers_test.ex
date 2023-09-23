defmodule Omc.LedgersTest do
  use Omc.DataCase, asyc: true
  alias Omc.Ledgers
  alias Omc.Ledgers.{Ledger, LedgerTx}
  import Omc.LedgersFixtures

  # describe "get_ledger/2" do
  #   test "when ledger does not exist, return null" do
  #     assert Ledgers.get_ledger(:local, "some_user_id", "IRR") == nil
  #   end
  #
  #   test "returns ledger if it exists" do
  #     %{id: id} = ledger = ledger_fixture()
  #     assert %{id: ^id} = Ledgers.get_ledger(ledger.user_type, ledger.user_id, "IRR")
  #   end
  # end

  # describe "create_ledger/1" do
  #   test "requires user_type, user_id be set" do
  #     {:error, changeset} = Ledgers.create_ledger(%{})
  #
  #     assert %{
  #              user_type: ["can't be blank"],
  #              user_id: ["can't be blank"]
  #            } = errors_on(changeset)
  #   end
  #
  #   test "empty user_id is not accepted" do
  #     {:error, changeset} = Ledgers.create_ledger(%{user_type: :local, user_id: ""})
  #
  #     assert %{
  #              user_id: ["can't be blank"]
  #            } = errors_on(changeset)
  #   end
  #
  #   test "duplicate ledger with same user_id, user_type raises" do
  #     ledger1 = ledger_fixture()
  #
  #     assert_raise Ecto.ConstraintError,
  #                  fn ->
  #                    Ledgers.create_ledger(%{
  #                      user_type: ledger1.user_type,
  #                      user_id: ledger1.user_id
  #                    })
  #                  end
  #   end
  #
  #   test "default credit value is zero" do
  #     assert {:ok, %{credit: 0}} =
  #              Ledgers.create_ledger(%{user_type: :telegram, user_id: "123456"})
  #   end
  # end
  #
  # describe "update_ledger/1" do
  #   setup do
  #     %{ledger: ledger_fixture()}
  #   end
  #
  #   test "credit change is reauired", %{ledger: ledger} do
  #     {:error, changeset} = Ledgers.update_ledger(ledger, %{})
  #     assert %{credit: ["did not change"]} = errors_on(changeset)
  #   end
  #
  #   test "credit change should only affect :credit field", %{ledger: ledger} do
  #     {:ok, updated_ledger} =
  #       Ledgers.update_ledger(ledger, %{user_id: "new_user_id", credit: 123.45})
  #
  #     assert updated_ledger.user_id == ledger.user_id
  #     assert updated_ledger.credit == Decimal.new("123.45")
  #   end
  # end

  describe "create_ledger_tx/1" do
    # setup %{} do
    #   %{ledger: ledger_fixture()}
    # end

    test "ledger itself id created by a tx" do
      {:ok,
       %{
         ledger: %Ledger{} = ledger,
         ledger_updated: %Ledger{} = ledger_updated,
         ledger_tx: %LedgerTx{} = _ledger_tx
       }} = Ledgers.create_ledger_tx(valid_ledger_tx_attrubutes(%{amount: 200, type: :credit}))

      assert ledger.credit == 0
      assert ledger_updated.credit == 200

      assert ledger_updated ==
               Ledgers.get_ledger(%{user_type: ledger.user_type, user_id: ledger.user_id})
    end

    # test "all fileds are required for non :manual ledger creation" do
    #   {:error, changeset} = Ledgers.create_ledger_tx(%{type: :manual})
    #
    #   assert %{
    #            ledger_id: ["can't be blank"],
    #            amount: ["can't be blank"],
    #            context: ["can't be blank"],
    #            context_ref: ["can't be blank"]
    #          } = errors_on(changeset)
    # end
    #
    # test "credit type should must increase parent ledger credit", %{ledger: ledger} do
    #   {:ok, ledger_tx} =
    #     Ledgers.create_ledger_tx(%{
    #       ledger_id: ledger.id,
    #       type: :credit,
    #       amount: 2000,
    #       context: :manual
    #     })
    #
    #   new_ledger = Ledgers.get_ledger(ledger.user_type, ledger.user_id, "IRR")
    #   assert ledger.credit + 2000 == new_ledger.credit
    # end
  end
end
