defmodule Omc.Telegram.CallbackCredit do
  alias Omc.Users
  use Omc.Telegram.CallbackQuery
  alias Omc.Usages
  alias Omc.Payments

  @impl true
  def do_process(args = %{user: user, callback_args: callback_args}) do
    case callback_args do
      ["not_possible_arg_redirect"] ->
        {:redirect, "main", %{message: "Dialyzer trick"}}

      [] ->
        {:ok,
         args
         |> Map.put_new(:message, "")
         |> put_common_args()}

      [amount] ->
        {:ok, _} = Users.upsert_user_info(user)

        Payments.create_payment_request(
          Application.get_env(:omc, :ipgs)[:default],
          user |> Map.put(:money, Money.parse!(amount))
        )
        |> case do
          {:ok, _} ->
            {:ok, args |> Map.put(:message, "Payment request created.") |> put_common_args()}

          {:error, error} ->
            Logger.error("Failed creating payment request; #{inspect(error)}")
            {:error, args |> Map.put(:message, "Failed creating payment request!")}
        end
    end
  end

  @impl true
  def get_text(%{usage_state: usage_state, payment_requests: prs}) do
    ~s"""
    __*Your Credit\\(s\\).*__
    *#{ledgers_text(usage_state.ledgers)}*

    Choose an amount for credit increase; Once a pay botton pressed, a new payment request is added on top of the following list having a link which can be used for payment.

    *Your Last Payment Requests* \\(most recent one is on top\\)
    __*Payable*__, __*Pay Link*__, __*Received Sum*__
    #{payment_requests_text(prs)} 
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

  defp ledgers_text([]) do
    Money.new(0) |> Money.to_string()
  end

  defp ledgers_text(ledgers) do
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

  defp payment_requests_text([]), do: "- no payment request yet."

  defp payment_requests_text(prs) do
    prs
    |> Enum.reduce("", fn item, acc ->
      acc <>
        "#{if(acc != "", do: "\n")}" <> payment_request_text(item)
    end)
  end

  defp payment_request_text(item) do
    "- _#{item.money}, [Pay Link](#{item.url}), #{Money.new(item.paid_sum || 0, item.money.currency)}_"
  end

  defp put_common_args(args = %{user: user = %{user_type: user_type, user_id: user_id}}) do
    args
    |> Map.put(:usage_state, Usages.get_user_usage_state(user))
    |> Map.put(
      :payment_requests,
      Payments.list_payment_requests(
        page: 1,
        limit: 3,
        user_id: user_id,
        user_type: user_type
      )
    )
  end
end
