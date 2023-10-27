defmodule Omc.PaymentsTest do
  alias Omc.Payments.PaymentState
  alias Omc.LedgersFixtures
  alias Omc.Payments
  alias Omc.Payments.PaymentRequest
  alias Omc.PaymentProviderWpMock
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
      money = Money.new(1300)
      url = OmcWeb.Endpoint.url() <> "/api/payment/wp"

      payment_request =
        payment_request_fixture(:wp, %{user_type: user_type, user_id: user_id, money: money})

      assert %PaymentRequest{
               user_id: ^user_id,
               user_type: ^user_type,
               money: ^money,
               ipg: :wp,
               type: :pull,
               url: ^url
             } = payment_request
    end

    test "should not create a PaymentRequest record on failed request to provider", %{
      user_id: user_id,
      user_type: user_type
    } do
      PaymentProviderWpMock
      |> expect(:send_payment_request, fn %{money: _, ref: _} ->
        {:error, :some_reason}
      end)

      assert {:error, :some_reason} =
               Payments.create_payment_request(:wp, %{
                 user_type: user_type,
                 user_id: user_id,
                 money: Money.new(1300)
               })
    end
  end

  describe "callback/3" do
    setup %{} do
      %{payment_request: payment_request_fixture()}
    end

    test "callback causing :pending state", %{
      payment_request: payment_request
    } do
      PaymentProviderWpMock
      |> expect(:callback, fn _params, _body ->
        {:ok,
         %{
           state: :pending,
           ref: payment_request.ref,
           data: %{"data_field" => "data_field_value"}
         }, %{"res_field" => "res_field_value"}}
      end)

      {:ok, %{"res_field" => "res_field_value"}} = Payments.callback(:wp, nil, nil)
      payment_request = Payments.get_payment_request(payment_request.ref)
      assert payment_request.payment_states |> length() == 1

      assert %PaymentState{
               state: :pending,
               data: %{"data_field" => "data_field_value"}
             } = payment_request.payment_states |> List.first()
    end

    test "callback having not exising ref" do
      PaymentProviderWpMock
      |> expect(:callback, fn _params, _body ->
        {:ok,
         %{
           state: :pending,
           ref: "some_not_existing_ref",
           data: nil
         }, nil}
      end)
      |> expect(:not_found_response, fn -> :not_found end)

      assert {:error, :not_found} = Payments.callback(:wp, nil, nil)
    end

    test "reapeating callback causing :pending state has no effect", %{
      payment_request: payment_request
    } do
      PaymentProviderWpMock
      |> expect(:callback, 2, fn _params, _body ->
        {:ok,
         %{
           state: :pending,
           ref: payment_request.ref,
           data: %{"data_field" => "data_field_value"}
         }, nil}
      end)

      # first callback
      {:ok, nil} = Payments.callback(:wp, nil, nil)
      payment_request = Payments.get_payment_request(payment_request.ref)
      assert payment_request.payment_states |> length() == 1

      assert %PaymentState{
               state: :pending
             } = payment_request.payment_states |> List.first()

      # second one
      {:ok, nil} = Payments.callback(:wp, nil, nil)
      payment_request = Payments.get_payment_request(payment_request.ref)
      assert payment_request.payment_states |> length() == 1

      assert %PaymentState{
               state: :pending
             } = payment_request.payment_states |> List.first()
    end
  end
end
