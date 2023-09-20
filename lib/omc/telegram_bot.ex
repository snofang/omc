defmodule Omc.TelegramBot do
  use Telegram.Bot

  @impl Telegram.Bot
  # def handle_update(
  #       %{
  #         "message" => %{
  #           "text" => "/sleep" <> seconds_arg,
  #           "chat" => %{"id" => chat_id},
  #           "message_id" => message_id
  #         }
  #       },
  #       token
  #     ) do
  #   seconds = seconds_arg |> parse_seconds_arg()
  #   Command.sleep(token, chat_id, message_id, seconds)
  # end

  def handle_update(update, token) do
    unknown_message = "Unknown message:\n\n```\n#{inspect(update, pretty: true)}\n```"

    case update do
      %{"message" => %{"message_id" => message_id, "chat" => %{"id" => chat_id}}} ->
        Telegram.Api.request(token, "sendMessage",
          chat_id: chat_id,
          reply_to_message_id: message_id,
          parse_mode: "MarkdownV2",
          text: unknown_message
        )

      _ ->
        Logger.debug(unknown_message)
    end
  end
end
