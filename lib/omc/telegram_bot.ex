defmodule Omc.TelegramBot do
  alias Omc.Telegram.TelegramUtils
  alias Omc.Telegram.TelegramApi
  alias Omc.Telegram.CallbackMain
  use Telegram.Bot

  @impl Telegram.Bot
  def handle_update(update, token) do
    try do
      case update do
        %{"message" => %{"text" => text, "chat" => %{"id" => chat_id}}} ->
          if String.match?(text, ~r/start/) do
            {:ok, _} =
              TelegramApi.send_message(
                token,
                chat_id,
                CallbackMain.get_text(%{}),
                CallbackMain.get_markup(%{})
              )
          else
            {:ok, _} =
              TelegramApi.send_message(token, chat_id, "Please use */start* command.", [[]])
          end

        _message = %{
          "callback_query" => %{
            "id" => callback_query_id,
            "data" => data,
            "from" => %{"id" => _from_id},
            "message" => %{"message_id" => message_id, "chat" => %{"id" => chat_id}}
          }
        } ->
          {callback, args} = data |> TelegramUtils.decode_callback_data()

          {:ok, _} =
            TelegramUtils.handle_callback(callback, %{
              token: token,
              callback_query_id: callback_query_id,
              chat_id: chat_id,
              message_id: message_id,
              callback_args: args
            })

        _ ->
          Logger.debug("Unknown message:\n\n```\n#{inspect(update, pretty: true)}\n```")
      end
    rescue
      error ->
        if(update["callback_query"]["message"]["chat"]["id"]) do
          TelegramApi.send_message(
            token,
            update["callback_query"]["message"]["chat"]["id"],
            "Sorry! Some problem happened.\nWe'll be back soon.\nIn the meanwhile please try /start again.",
            [[]]
          )
        end

        Logger.error("""
        processing telegram's update message failed; 
        Update Message:
          #{inspect(update, pretty: true)}
        Error: 
          #{Exception.format(:error, error, __STACKTRACE__)}
        """)
    end
  end
end
