defmodule Omc.PaymentsTest do
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

    test "reapeating callback causing same state insert each of them", %{
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
end
