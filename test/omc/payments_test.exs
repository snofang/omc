defmodule Omc.PaymentsTest do
  use Omc.DataCase, async: true
  alias Omc.Ledgers
  alias Omc.Payments.PaymentState
  alias Omc.LedgersFixtures
  alias Omc.Payments
  alias Omc.Payments.PaymentRequest
  alias Omc.PaymentProviderMock
  import Mox
  import Omc.PaymentFixtures

  # setup %{} do
  #   stub(PaymentProviderMock, :get_paid_ref, fn _data -> nil end)
  #   :ok
  # end

  describe "create_payment_request/2" do
    setup %{} do
      %{user_id: LedgersFixtures.unique_user_id(), user_type: :telegram}
    end

    test "should create a PaymentRequest record on success request to provider", %{
      user_id: user_id,
      user_type: user_type
    } do
      PaymentProviderMock
      |> stub(:send_payment_request, fn attrs ->
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
      PaymentProviderMock
      |> stub(:send_payment_request, fn %{} ->
        {:error, :some_reason}
      end)

      assert {:error, :some_reason} =
               Payments.create_payment_request(:oxapay, %{
                 user_type: user_type,
                 user_id: user_id,
                 money: Money.new(1300)
               })
    end

    test "ref should be unique for each ipg",
         user = %{
           user_id: _,
           user_type: _
         } do
      PaymentProviderMock
      |> stub(:send_payment_request, fn attrs ->
        {:ok,
         attrs
         |> Map.put(:data, %{a: 1})
         |> Map.put(:ref, "123")
         |> Map.put(:url, "https://example.com/pay/123")
         |> Map.put(:type, :push)}
      end)

      args = user |> Map.put(:money, Money.new(1300))

      # first request
      {:ok, _} = Payments.create_payment_request(:oxapay, args)

      # second request
      assert_raise(Ecto.ConstraintError, fn ->
        Payments.create_payment_request(:oxapay, args)
      end)

      # third request; different ipg
      assert {:ok, _} = Payments.create_payment_request(:nowpayments, args)
    end
  end

  describe "callback/3" do
    setup %{} do
      start_supervised(Payments)
      Ecto.Adapters.SQL.Sandbox.allow(Omc.Repo, self(), Process.whereis(Omc.Payments))
      %{payment_request: payment_request_fixture()}
    end

    test "callback causing :pending state", %{
      payment_request: payment_request
    } do
      PaymentProviderMock
      |> stub(:callback, fn _data ->
        {:ok,
         %{
           state: :pending,
           ref: payment_request.ref,
           data: %{"data_field" => "data_field_value"}
         }, "OK"}
      end)

      {:ok, "OK"} = Payments.callback(:oxapay, nil)
      payment_request = Payments.get_payment_request(payment_request.ref)
      assert payment_request.payment_states |> length() == 1

      assert %PaymentState{
               state: :pending,
               data: %{"data_field" => "data_field_value"}
             } = payment_request.payment_states |> List.first()
    end

    test "callback having not exising ref" do
      PaymentProviderMock
      |> stub(:callback, fn _data ->
        {:ok,
         %{
           state: :pending,
           ref: "some_not_existing_ref",
           data: nil
         }, nil}
      end)

      assert {:error, :not_found} = Payments.callback(:oxapay, nil)
    end

    test "reapeating callback causing same state inserts for each of them", %{
      payment_request: payment_request
    } do
      PaymentProviderMock
      |> stub(:callback, fn _data ->
        {:ok,
         %{
           state: :pending,
           ref: payment_request.ref,
           data: %{"data_field" => "data_field_value"}
         }, nil}
      end)

      # first callback
      {:ok, nil} = Payments.callback(:oxapay, nil)
      payment_request = Payments.get_payment_request(payment_request.ref)
      assert payment_request.payment_states |> length() == 1

      assert %PaymentState{
               state: :pending
             } = payment_request.payment_states |> List.first()

      # second one
      {:ok, nil} = Payments.callback(:oxapay, nil)
      payment_request = Payments.get_payment_request(payment_request.ref)
      assert payment_request.payment_states |> length() == 2

      assert %PaymentState{
               state: :pending
             } = payment_request.payment_states |> Enum.at(1)
    end

    test ":done callback should update ledger", %{payment_request: pr} do
      PaymentProviderMock
      |> stub(:callback, fn _data ->
        {:ok,
         %{
           state: :done,
           ref: pr.ref,
           data: %{"data_field" => "data_field_value"}
         }, "OK"}
      end)
      |> stub(:get_paid_money!, fn _data, _currency -> Money.new(1234) end)
      |> stub(:get_paid_ref, fn _data -> nil end)
      |> allow(self(), Process.whereis(Payments))

      {:ok, "OK"} = Payments.callback(:oxapay, nil)

      assert Ledgers.get_ledger(%{user_type: pr.user_type, user_id: pr.user_id})
             |> then(& &1.credit) == 1234
    end

    test "already affected ledger should not updated by repetitive :done callbacks", %{
      payment_request: pr
    } do
      paid_ref = System.unique_integer([:positive]) |> to_string()

      PaymentProviderMock
      |> stub(:callback, fn _data ->
        {:ok,
         %{
           state: :done,
           ref: pr.ref,
           data: %{"data_field" => "data_field_value"}
         }, "OK"}
      end)
      |> stub(:get_paid_money!, fn _data, _currency -> Money.new(1234) end)
      |> stub(:get_paid_ref, fn _data -> paid_ref end)
      |> allow(self(), Process.whereis(Payments))

      # first :done callback
      {:ok, "OK"} = Payments.callback(:oxapay, nil)

      assert Ledgers.get_ledger(%{user_type: pr.user_type, user_id: pr.user_id})
             |> then(& &1.credit) == 1234

      assert Payments.get_payment_request(pr.ref)
             |> then(& &1.payment_states)
             |> length() == 1

      # second :done callback
      {:ok, "OK"} = Payments.callback(:oxapay, nil)

      assert Ledgers.get_ledger(%{user_type: pr.user_type, user_id: pr.user_id})
             |> then(& &1.credit) == 1234

      assert Payments.get_payment_request(pr.ref)
             |> then(& &1.payment_states)
             |> length() == 2
    end

    test "repetitive :done callbacks having different payment_request_item_ref", %{
      payment_request: pr
    } do
      PaymentProviderMock
      |> stub(:callback, fn _data ->
        {:ok,
         %{
           state: :done,
           ref: pr.ref,
           data: %{"data_field" => "data_field_value"}
         }, "OK"}
      end)
      |> stub(:get_paid_money!, fn _data, _currency -> Money.new(1234) end)
      |> stub(:get_paid_ref, fn _data -> System.unique_integer([:positive]) |> to_string() end)
      |> allow(self(), Process.whereis(Payments))

      # first :done callback
      {:ok, "OK"} = Payments.callback(:nowpayments, nil)

      assert Ledgers.get_ledger(%{user_type: pr.user_type, user_id: pr.user_id})
             |> then(& &1.credit) == 1234

      assert Payments.get_payment_request(pr.ref)
             |> then(& &1.payment_states)
             |> length() == 1

      # second :done callback
      {:ok, "OK"} = Payments.callback(:nowpayments, nil)

      assert Ledgers.get_ledger(%{user_type: pr.user_type, user_id: pr.user_id})
             |> then(& &1.credit) == 2468

      assert Payments.get_payment_request(pr.ref)
             |> then(& &1.payment_states)
             |> length() == 2
    end
  end

  describe "list_payment_requests/1" do
    test "limit and pagination and order" do
      %{id: id1} = payment_request_fixture()
      %{id: id2} = done_payment_request_fixture()
      %{id: id3} = payment_request_fixture()

      assert [%{id: ^id3}] = Payments.list_payment_requests(page: 1, limit: 1)
      assert [%{id: ^id2}] = Payments.list_payment_requests(page: 2, limit: 1)
      assert [%{id: ^id1}] = Payments.list_payment_requests(page: 3, limit: 1)
    end

    test "user_type filter" do
      %{id: id1} = payment_request_fixture(%{user_type: :local})
      %{id: _id2} = payment_request_fixture(%{user_type: :telegram})

      assert [%{id: ^id1}] = Payments.list_payment_requests(user_type: :local)
    end

    test "user_id filter" do
      %{id: id1} = payment_request_fixture(%{user_id: "12345"})
      %{id: _id2} = payment_request_fixture(%{user_id: "67890"})

      assert [%{id: ^id1}] = Payments.list_payment_requests(user_id: "234")
    end

    test "payment paid? filter" do
      %{id: _id1} = payment_request_fixture()
      %{id: id2} = done_payment_request_fixture()
      %{id: _id3} = payment_request_fixture()

      assert [%{id: ^id2}] = Payments.list_payment_requests(paid?: true)
    end

    test "should contain paid_sum" do
      %{id: id1} = payment_request_fixture()
      %{id: id2} = done_payment_request_fixture()
      pr3 = %{id: id3, money: %{amount: amount}} = done_payment_request_fixture()
      payment_state_by_callback_fixture(pr3, :done, "1")
      payment_state_by_callback_fixture(pr3, :done, "2")
      pr3_paid_sum = amount * 3

      assert [
               %{id: ^id3, paid_sum: ^pr3_paid_sum},
               %{id: ^id2, paid_sum: ^amount},
               %{id: ^id1, paid_sum: nil}
             ] = Payments.list_payment_requests()
    end
  end

  describe "send_state_inquiry_request/1" do
    setup %{} do
      start_supervised(Payments)
      Ecto.Adapters.SQL.Sandbox.allow(Omc.Repo, self(), Process.whereis(Omc.Payments))
      %{payment_request: payment_request_fixture()}
    end

    test "should create new PaymentState on success", %{payment_request: pr} do
      PaymentProviderMock
      |> stub(:send_state_inquiry_request, fn _ ->
        {:ok, %{state: :pending, data: %{"res_key" => "res_value"}}}
      end)

      {:ok, payment_state} = Payments.send_state_inquiry_request(pr)
      assert %{state: :pending, data: %{"res_key" => "res_value"}} = payment_state
      assert payment_state.payment_request_id == pr.id
    end

    test "On error, no PaymentState is created", %{payment_request: pr} do
      PaymentProviderMock
      |> stub(:send_state_inquiry_request, fn _ ->
        {:error, :some_special_error}
      end)

      {:error, :some_special_error} = Payments.send_state_inquiry_request(pr)

      assert Payments.get_payment_request(pr.ref)
             |> then(& &1.payment_states) == []
    end

    test "On done state, ledger should be updated", %{payment_request: pr} do
      PaymentProviderMock
      |> stub(:send_state_inquiry_request, fn _ ->
        {:ok, %{state: :done, data: %{"res_key" => "res_value"}}}
      end)
      |> stub(:get_paid_money!, fn _data, _currency -> Money.new(1234) end)
      |> stub(:get_paid_ref, fn _data -> nil end)
      |> allow(self(), Process.whereis(Payments))

      {:ok, payment_state} = Payments.send_state_inquiry_request(pr)
      assert %{state: :done, data: %{"res_key" => "res_value"}} = payment_state

      assert Ledgers.get_ledger(%{user_type: pr.user_type, user_id: pr.user_id})
             |> then(& &1.credit) == 1234
    end

    test "already affected ledger should not updated by repetitive :done callbacks", %{
      payment_request: pr
    } do
      PaymentProviderMock
      |> stub(:send_state_inquiry_request, fn _ ->
        {:ok, %{state: :done, data: %{"res_key" => "res_value"}}}
      end)
      |> stub(:get_paid_money!, fn _data, _currency -> Money.new(1234) end)
      |> stub(:get_paid_ref, fn _data -> nil end)
      |> allow(self(), Process.whereis(Payments))

      # first inquiry 
      {:ok, _} = Payments.send_state_inquiry_request(pr)

      assert Ledgers.get_ledger(%{user_type: pr.user_type, user_id: pr.user_id})
             |> then(& &1.credit) == 1234

      # second inquiry 
      {:ok, _} = Payments.send_state_inquiry_request(pr)

      assert Ledgers.get_ledger(%{user_type: pr.user_type, user_id: pr.user_id})
             |> then(& &1.credit) == 1234
    end

    test "On non done state, ledger should not updated", %{payment_request: pr} do
      # before any inquiry 
      assert Ledgers.get_ledger(%{user_type: pr.user_type, user_id: pr.user_id}) == nil

      # pending state
      PaymentProviderMock
      |> stub(:send_state_inquiry_request, fn _ ->
        {:ok, %{state: :pending, data: %{"res_key" => "res_value"}}}
      end)

      {:ok, _} = Payments.send_state_inquiry_request(pr)
      assert Ledgers.get_ledger(%{user_type: pr.user_type, user_id: pr.user_id}) == nil

      # failed state
      PaymentProviderMock
      |> stub(:send_state_inquiry_request, fn _ ->
        {:ok, %{state: :failed, data: %{"res_key" => "res_value"}}}
      end)

      {:ok, _} = Payments.send_state_inquiry_request(pr)
      assert Ledgers.get_ledger(%{user_type: pr.user_type, user_id: pr.user_id}) == nil
    end
  end
end
