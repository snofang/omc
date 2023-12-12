defmodule Omc.Telegram.CallbackCredit do
  use Omc.Telegram.CallbackQuery
  alias Omc.Usages
  alias Omc.Payments

  @impl true
  def do_process(args = %{user: user, callback_args: callback_args}) do
    case callback_args do
      ["not_possible_arg_redirect"] ->
        {:redirect, "main", %{message: "Dialyzer trick"}}

      [] ->
        {:ok, args |> Map.put_new(:message, "")}

      [amount | []] ->
        Payments.create_payment_request(:oxapay, user |> Map.put(:money, Money.parse!(amount)))
        |> case do
          {:ok, _} ->
            {:ok, args |> Map.put(:message, "Payment request created.")}

          {:error, _} ->
            {:error, args |> Map.put(:message, "Failed creating payment request!")}
        end
    end
  end

  @impl true
  def get_text(%{user: user}) do
    usage_state = Usages.get_user_usage_state(user)

    ~s"""
    __*Your Credit\\(s\\).*__
    *#{ledgers_rows(usage_state.ledgers)}*

    Choose an amount for credit increase; Once a pay botton pressed, a new payment request is added on top of the following list with a link which can be used for payment.

    *Your Payment Requests* \\(most recent one is on top\\)
    __*Amount, Status*__
    #{last_payment_requests(user)} 
    """
  end

  @impl true
  def get_markup(%{user: _user, callback_args: _}) do
    [
      [
        %{text: "Pay #{Money.new(200)}", callback_data: "Credit-2"},
        %{text: "Pay #{Money.new(500)}", callback_data: "Credit-5"}
      ],
      [
        %{text: "Pay #{Money.new(1000)}", callback_data: "Credit-10"},
        %{text: "Pay #{Money.new(2000)}", callback_data: "Credit-20"}
      ],
      [
        %{text: "<< back", callback_data: "Main"},
        %{text: "Refresh", callback_data: "Credit"}
      ]
    ]
  end

  defp ledgers_rows([]) do
    Money.new(0) |> Money.to_string()
  end

  defp ledgers_rows(ledgers) do
    ledgers
    |> Enum.reduce("", fn l, result ->
      result
      |> case do
        "" ->
          ""

        r ->
          "\n" <> r
      end
      |> then(fn r -> r <> "- " <> (Money.new(l.credit, l.currency) |> Money.to_string()) end)
    end)
  end

  defp last_payment_requests(%{user_id: user_id, user_type: user_type}) do
    Payments.list_payment_requests(page: 1, limit: 5, user_id: user_id, user_type: user_type)
    |> Enum.reduce("", fn item, acc ->
      acc <>
        "#{if(acc != "", do: "\n")}- _#{item.money}, #{item.state || "'new'"},  [Pay Link](#{item.url})_"
    end)
  end
end
