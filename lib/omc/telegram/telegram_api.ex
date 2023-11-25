defmodule Omc.Telegram.TelegramApi do
  @callback answer_callback(token :: binary(), callback_query_id :: binary(), text :: binary()) ::
              term()
  @callback edit_message_markup(
              token :: binary(),
              chat_id :: binary(),
              message_id :: integer(),
              reply_markup :: [[map()]]
            ) ::
              term()
  @callback edit_message_text(
              token :: binary(),
              chat_id :: binary(),
              message_id :: integer(),
              text :: binary()
            ) :: term()

  @callback send_message(
              token :: binary(),
              chat_id :: binary(),
              text :: binary(),
              inline_keyboard :: [[map()]]
            ) :: term()

  def send_message(token, chat_id, text, inline_keyboard),
    do: impl().send_message(token, chat_id, text, inline_keyboard)

  def edit_message_text(token, chat_id, message_id, text),
    do: impl().edit_message_text(token, chat_id, message_id, text)

  def edit_message_markup(token, chat_id, message_id, reply_markup),
    do: impl().edit_message_markup(token, chat_id, message_id, reply_markup)

  def answer_callback(token, callback_query_id, text),
    do: impl().answer_callback(token, callback_query_id, text)

  defp impl(), do: Application.get_env(:omc, :telegram)[:api_impl]
end
