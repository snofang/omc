defmodule Omc.Telegram.CallbackUsage do
  use Omc.Telegram.CallbackQuery
  alias Omc.Usages
  alias Omc.ServerAccUsers

  @impl true
  def get_text(%{user: user, data_args: _}) do
    usage_state = Usages.get_usage_state(user)

    ~s"""
    *Your Credit\\(s\\).*
    ----------------------
    #{ledgers_table(usage_state.ledgers)}
    ----------------------

    """

    # ```
    # #{ledgers_table(usage_state.ledgers)}
    # ```
    # """
  end

  @impl true
  def get_markup(%{user: user, data_args: _}) do
    user
    |> ServerAccUsers.list_active_accs()
    |> markup()
    |> then(&(&1 ++ [[markup_item("<< back", "Main"), markup_item("Add Credit", "AddCredit")]]))
  end

  defp markup(active_accs) do
    active_accs
    |> Enum.reduce([[]], fn %{sa_name: sa_name, sa_id: _sa_id, sau_id: sau_id}, acc ->
      case acc |> List.first() do
        [] ->
          [[markup_item(sa_name, "usage_#{sau_id}")]]

        [item | []] ->
          acc
          |> List.replace_at(0, [markup_item(sa_name, "usage_#{sau_id}") | [item]])

        _ ->
          [[markup_item(sa_name, "usage_#{sau_id}")] | acc]
      end
    end)
  end

  defp ledgers_table([]) do
    Money.new(0) |> Money.to_string()
  end

  defp ledgers_table(ledgers) do
    ledgers
    |> Enum.map(fn l -> (Money.new(l.credit, l.currency) |> Money.to_string()) <> "\n" end)

    # ledgers
    # |> ledgers_rows()
    # |> Table.new(["Currency", "Credit"])
    # |> Table.render!()
  end

  def ledgers_rows([]) do
    [["USD", "-.--"]]
  end

  def ledgers_rows(ledgers) do
    ledgers |> Enum.map(&[&1.currency, &1.credit])
  end

  # @doc false
  # def my_balance(token, callback_query_id, chat_id, message_id, []) do
  #   user = %{user_type: :telegram, user_id: chat_id |> to_string()}
  #   usage_state = Usages.get_usage_state(user)
  #
  #   edit_message_text(token, chat_id, message_id, TelegramUtils.ledgers_text(usage_state.ledgers))
  #   |> IO.inspect(label: "--- edit text resutl ---")
  #
  #   edit_message_markup(
  #     token,
  #     chat_id,
  #     message_id,
  #     ServerAccUsers.list_active_accs(user)
  #     |> TelegramUtils.usages_state_active_accs_markup()
  #     |> then(&(&1 ++ [[TelegramUtils.markup_item("<< back", "main")]]))
  #   )
  #
  #   answer_callback(token, callback_query_id, "Succeeded!")
  # end

  # defp get_usage_state(user_id) do
  #   Usages.get_usage_state(%{user_type: :telegram, user_id: user_id |> to_string()})
  #   |> TelegramUtils.to_string_ledgers()
  #   |> IO.inspect(label: "----- produced text -----")
  # end
end
