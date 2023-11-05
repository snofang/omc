defmodule Omc.PaymentsTest do
  alias Omc.Ledgers
  alias Omc.Common.Utils
  alias Omc.Payments.PaymentState
  alias Omc.LedgersFixtures
  alias Omc.Payments
  alias Omc.Payments.PaymentRequest
  alias Omc.PaymentProviderOxapayMock
  use Omc.DataCase, async: true
  import Mox
  import Omc.PaymentFixtures

  describe "create_payment_request/2" do
    setup %{} do
      %{user_id: LedgersFixtures.unique_user_id(), user_type: :telegram}
    end

    test "should create a PaymentRequest record on success request to provider", %{
      user_id: user_id,
      user_type: user_type
    } do
      PaymentProviderOxapayMock
      |> expect(:send_payment_request, fn attrs ->
        {:ok,
         attrs
         |> Map.put(:data, %{a: 1})
         |> Map.put(:ref, "123")
         |> Map.put(:url, "https://example.com/pay/123")
         |> Map.put(:type, :push)}
      end)

      money = Money.new(1300)

      {:ok, payment_request} =
        Payments.create_payment_request(:oxapay, %{
          user_type: user_type,
          user_id: user_id,
          money: money
        })

      assert %PaymentRequest{
               user_id: ^user_id,
               user_type: ^user_type,
               money: ^money,
               ipg: :oxapay,
               type: :push,
               data: %{a: 1},
               ref: "123",
               url: "https://example.com/pay/123"
             } = payment_request
    end

    test "should not create a PaymentRequest record on failed request to provider", %{
      user_id: user_id,
      user_type: user_type
    } do
      PaymentProviderOxapayMock
      |> expect(:send_payment_request, fn %{} ->
        {:error, :some_reason}
      end)

      assert {:error, :some_reason} =
               Payments.create_payment_request(:oxapay, %{
                 user_type: user_type,
                 user_id: user_id,
                 money: Money.new(1300)
               })
    end

    test "ref should be unique", %{
      user_id: user_id,
      user_type: user_type
    } do
      PaymentProviderOxapayMock
      |> expect(:send_payment_request, 2, fn attrs ->
        {:ok,
         attrs
         |> Map.put(:data, %{a: 1})
         |> Map.put(:ref, "123")
         |> Map.put(:url, "https://example.com/pay/123")
         |> Map.put(:type, :push)}
      end)

      money = Money.new(1300)

      # first request
      {:ok, _} =
        Payments.create_payment_request(:oxapay, %{
          user_type: user_type,
          user_id: user_id,
          money: money
        })

      # second request
      assert_raise(Ecto.ConstraintError, fn ->
        Payments.create_payment_request(:oxapay, %{
          user_type: user_type,
          user_id: user_id,
          money: money
        })
      end)
    end
  end

  describe "callback/3" do
    setup %{} do
      %{payment_request: payment_request_fixture()}
    end

    test "callback causing :pending state", %{
      payment_request: payment_request
    } do
      PaymentProviderOxapayMock
      |> expect(:callback, fn _params, _body ->
        {:ok,
         %{
           state: :pending,
           ref: payment_request.ref,
           data: %{"data_field" => "data_field_value"}
         }, "OK"}
      end)

      {:ok, "OK"} = Payments.callback(:oxapay, nil, nil)
      payment_request = Payments.get_payment_request(payment_request.ref)
      assert payment_request.payment_states |> length() == 1

      assert %PaymentState{
               state: :pending,
               data: %{"data_field" => "data_field_value"}
             } = payment_request.payment_states |> List.first()
    end

    test "callback having not exising ref" do
      PaymentProviderOxapayMock
      |> expect(:callback, fn _params, _body ->
        {:ok,
         %{
           state: :pending,
           ref: "some_not_existing_ref",
           data: nil
         }, nil}
      end)

      assert {:error, :not_found} = Payments.callback(:oxapay, nil, nil)
    end

    test "reapeating callback causing same state inserts each of them", %{
      payment_request: payment_request
    } do
      PaymentProviderOxapayMock
      |> expect(:callback, 2, fn _params, _body ->
        {:ok,
         %{
           state: :pending,
           ref: payment_request.ref,
           data: %{"data_field" => "data_field_value"}
         }, nil}
      end)

      # first callback
      {:ok, nil} = Payments.callback(:oxapay, nil, nil)
      payment_request = Payments.get_payment_request(payment_request.ref)
      assert payment_request.payment_states |> length() == 1

      assert %PaymentState{
               state: :pending
             } = payment_request.payment_states |> List.first()

      # second one
      {:ok, nil} = Payments.callback(:oxapay, nil, nil)
      payment_request = Payments.get_payment_request(payment_request.ref)
      assert payment_request.payment_states |> length() == 2

      assert %PaymentState{
               state: :pending
             } = payment_request.payment_states |> Enum.at(1)
    end
  end

  describe "get_payments_with_last_done_state/1" do
    setup %{} do
      %{payment_request: payment_request_fixture()}
    end

    test "returns payments done occured during passed duration", %{
      payment_request: payment_request
    } do
      payment_state_by_callback_fixture(payment_request, :done)
      assert [{^payment_request, %{state: :done}}] = Payments.get_payments_with_last_done_state(1)
    end

    test "payments which their state is update befor duration should not listed", %{
      payment_request: payment_request
    } do
      payment_state_by_callback_fixture(payment_request, :done)
      [{_, state}] = Payments.get_payments_with_last_done_state(1)

      state
      |> Ecto.Changeset.change(%{inserted_at: Utils.now(-5, :second)})
      |> Repo.update()

      assert [] = Payments.get_payments_with_last_done_state(1)
    end

    test "with multiple states and not :done state, there should be not result", %{
      payment_request: payment_request
    } do
      payment_state_by_callback_fixture(payment_request, :pending)
      payment_state_by_callback_fixture(payment_request, :pending)
      payment_state_by_callback_fixture(payment_request, :pending)
      assert [] = Payments.get_payments_with_last_done_state(1)
    end

    test "Multiple :done payments should result in multiple results", %{
      payment_request: payment_request
    } do
      payment_state_by_callback_fixture(payment_request, :done)
      done_payment_request_fixture()
      done_payment_request_fixture()

      assert Payments.get_payments_with_last_done_state(2) |> length() == 3
    end

    test "multiple :done states; last :done state should returned", %{
      payment_request: payment_request
    } do
      payment_state_by_callback_fixture(payment_request, :pending)
      payment_state_by_callback_fixture(payment_request, :done)
      payment_state_by_callback_fixture(payment_request, :done)

      {:ok, last_done_state} =
        %PaymentState{state: :done, payment_request_id: payment_request.id, data: %{}}
        |> Repo.insert()

      assert [{_, ^last_done_state}] = Payments.get_payments_with_last_done_state(2)
    end
  end

  describe "update_ledger/2" do
    setup %{} do
      %{payment_request: done_payment_request_fixture()}
    end

    test "should update user's ledger, by received actual amount" do
      PaymentProviderOxapayMock
      |> expect(:get_paid_money!, fn _, _ -> Money.new(1234, Utils.default_currency()) end)

      [{pr, ps}] = Payments.get_payments_with_last_done_state(1)
      {:ok, :ledger_updated} = Payments.update_ledger({pr, ps})

      assert Ledgers.get_ledger(%{user_type: pr.user_type, user_id: pr.user_id})
             |> then(& &1.credit) == 1234
    end

    test "already used done payments should be ignored" do
      PaymentProviderOxapayMock
      |> expect(:get_paid_money!, fn _, _ -> Money.new(1234, Utils.default_currency()) end)

      [{pr, ps}] = Payments.get_payments_with_last_done_state(1)
      {:ok, :ledger_updated} = Payments.update_ledger({pr, ps})
      {:ok, :ledger_unchanged} = Payments.update_ledger({pr, ps})

      assert Ledgers.get_ledger(%{user_type: pr.user_type, user_id: pr.user_id})
             |> then(& &1.credit) == 1234
    end
  end

  describe "update_ledgers/0" do
    test "should update all ledgers related to last done payment within specified duration" do
      PaymentProviderOxapayMock
      |> expect(:get_paid_money!, 2, fn _, _ -> Money.new(1234, Utils.default_currency()) end)

      pr1 = done_payment_request_fixture()
      pr2 = done_payment_request_fixture()
      Payments.update_ledgers(1)

      assert Ledgers.get_ledger(%{user_type: pr1.user_type, user_id: pr1.user_id})
             |> then(& &1.credit) == 1234

      assert Ledgers.get_ledger(%{user_type: pr2.user_type, user_id: pr2.user_id})
             |> then(& &1.credit) == 1234
    end

    test "already update ones are being ignored" do
      PaymentProviderOxapayMock
      |> expect(:get_paid_money!, 3, fn _, _ -> Money.new(1234, Utils.default_currency()) end)

      pr1 = done_payment_request_fixture()
      pr2 = done_payment_request_fixture()

      Payments.get_payments_with_last_done_state(5) |> List.first() |> Payments.update_ledger()
      Payments.update_ledgers(5)

      assert Ledgers.get_ledger(%{user_type: pr1.user_type, user_id: pr1.user_id})
             |> then(& &1.credit) == 1234

      assert Ledgers.get_ledger(%{user_type: pr2.user_type, user_id: pr2.user_id})
             |> then(& &1.credit) == 1234
    end

    test "in case of any exception the other ones should updated" do
      PaymentProviderOxapayMock
      |> expect(:get_paid_money!, 1, fn _, _ -> Money.new(1234, Utils.default_currency()) end)
      |> expect(:get_paid_money!, 1, fn _, _ -> raise "some error" end)
      |> expect(:get_paid_money!, 1, fn _, _ -> Money.new(1234, Utils.default_currency()) end)

      pr1 = done_payment_request_fixture()
      pr2 = done_payment_request_fixture()
      pr3 = done_payment_request_fixture()

      Payments.update_ledgers(5)

      assert Ledgers.get_ledger(%{user_type: pr1.user_type, user_id: pr1.user_id})
             |> then(& &1.credit) == 1234

      assert Ledgers.get_ledger(%{user_type: pr2.user_type, user_id: pr2.user_id}) == nil

      assert Ledgers.get_ledger(%{user_type: pr3.user_type, user_id: pr3.user_id})
             |> then(& &1.credit) == 1234
    end
  end
end
