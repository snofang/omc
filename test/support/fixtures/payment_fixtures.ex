defmodule Omc.PaymentFixtures do
  alias Omc.Payments.PaymentRequest
  alias Omc.UsersFixtures
  alias Omc.Payments
  alias Omc.PaymentProviderMock
  import Mox

  def payment_request_fixture(attrs \\ %{}) do
    PaymentProviderMock
    |> stub(:send_payment_request, fn %{ipg: _, money: _, user_type: _, user_id: _} ->
      ref = System.unique_integer([:positive])

      {
        :ok,
        %{
          data: %{"some_data_key" => "some_data_key_value"},
          ref: ref |> to_string(),
          url: "https://example.com/pay/" <> to_string(ref),
          type: :push
        }
      }
    end)

    {:ok, payment_request} =
      Payments.create_payment_request(
        # :oxapay,
        Application.get_env(:omc, :ipgs)[:default],
        Enum.into(attrs, %{
          user_type: :telegram,
          user_id: UsersFixtures.unique_user_id(),
          money: Money.new(10000)
        })
      )

    payment_request
  end

  def payment_state_by_callback_fixture(
        %PaymentRequest{} = payment_request,
        state,
        paid_ref \\ nil,
        money \\ nil
      )
      when is_atom(state) do
    ExUnit.Callbacks.start_supervised(Omc.Payments)
    Ecto.Adapters.SQL.Sandbox.allow(Omc.Repo, self(), Process.whereis(Omc.Payments))

    PaymentProviderMock
    |> stub(:callback, fn _data ->
      {:ok, %{state: state, ref: payment_request.ref, data: %{}}, :some_response}
    end)
    |> stub(:get_paid_money!, fn _data, _currency -> money || payment_request.money end)
    |> stub(:get_paid_ref, fn _data -> paid_ref end)
    |> allow(self(), Process.whereis(Omc.Payments))

    response = {:ok, :some_response} = Payments.callback(payment_request.ipg, %{})
    ExUnit.Callbacks.stop_supervised(Omc.Payments)
    response
  end

  def done_payment_request_fixture(attrs \\ %{}) do
    pr = payment_request_fixture(attrs)
    payment_state_by_callback_fixture(pr, :pending)
    payment_state_by_callback_fixture(pr, :pending)
    payment_state_by_callback_fixture(pr, :done)
    pr
  end

  def mock_payment_request(%{
        user_type: user_type,
        user_id: user_id,
        money: %{amount: amount, currency: currency}
      }) do
    PaymentProviderMock
    |> stub(:send_payment_request, fn %{
                                        user_id: ^user_id,
                                        user_type: ^user_type,
                                        money: %{amount: ^amount, currency: ^currency}
                                      } ->
      {:ok,
       %{
         data: %{},
         ref: System.unique_integer([:positive]) |> to_string(),
         url: "http://some-url.com/pay",
         type: :push
       }}
    end)
  end
end
