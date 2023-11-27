defmodule Omc.Telegram.CallbackAddCredit do
  alias Omc.Payments
  use Omc.Telegram.CallbackQuery

  @impl true
  def get_text(args) do
    if args.data_args, do: create_payment_request(args.data_args |> List.first(), args.user)

    ~s"""
    From the bottons below select the desired amount you what to add to your credit. Once a pay botton pressed, a new payment request is added at the top of the list which can be used to do the payment.

    *Your Payment Requests* \\(most recent one is on top\\)
    __*Amount, Status*__
    #{last_payment_requests(args.user)} 
    """
  end

  @impl true
  def get_markup(_args) do
    [
      [
        %{text: "Pay #{Money.new(200)}", callback_data: "AddCredit-2"},
        %{text: "Pay #{Money.new(500)}", callback_data: "AddCredit-5"}
      ],
      [
        %{text: "Pay #{Money.new(1000)}", callback_data: "AddCredit-10"},
        %{text: "Pay #{Money.new(2000)}", callback_data: "AddCredit-20"}
      ],
      [
        %{text: "<< back", callback_data: "Usage"},
        %{text: "Refresh", callback_data: "AddCredit"}
      ]
    ]
  end

  defp last_payment_requests(%{user_id: user_id, user_type: user_type}) do
    Payments.list_payment_requests(page: 1, limit: 10, user_id: user_id, user_type: user_type)
    |> Enum.reduce("", fn item, acc ->
      acc <>
        "#{if(acc != "", do: "\n")}- _#{item.money}, #{item.state || "'new'"},  [Pay Link](#{item.url})_"
    end)
  end

  defp create_payment_request(amount, %{user_id: _, user_type: _} = user) do
    Payments.create_payment_request(:oxapay, user |> Map.put(:money, Money.parse!(amount)))
  end
end
