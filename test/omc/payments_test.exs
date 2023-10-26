defmodule Omc.PaymentsTest do
  alias Omc.LedgersFixtures
  alias Omc.Payments
  alias Omc.Payments.PaymentRequest
  alias Omc.PaymentProviderMock
  use Omc.DataCase, async: true
  import Mox

  describe "create_payment_request/2" do
    setup %{} do
      url = OmcWeb.Endpoint.url() <> "/api/payment/wp"
      %{user_id: LedgersFixtures.unique_user_id(), user_type: :telegram, url: url}
    end

    test "should create a PaymentRequest record on success request to provider", %{
      user_id: user_id,
      user_type: user_type,
      url: url
    } do
      PaymentProviderMock
      |> expect(:send_payment_request, fn %{money: _, ref: _} ->
        {:ok, url}
      end)

      money = Money.new(1300)

      {:ok, payment_request} =
        Payments.create_payment_request(:wp, %{
          user_type: user_type,
          user_id: user_id,
          money: money
        })

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
      PaymentProviderMock
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
end
