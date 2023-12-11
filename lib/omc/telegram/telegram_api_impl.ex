defmodule Omc.Telegram.TelegramApiImpl do
  @behaviour Omc.Telegram.TelegramApi

  @impl true
  def answer_callback(token, callback_query_id, text) do
    Telegram.Api.request(token, "answerCallbackQuery",
      callback_query_id: callback_query_id,
      text: text
    )
  end

  @impl true
  def edit_message_markup(token, chat_id, message_id, inline_keyboard) do
    Telegram.Api.request(token, "editMessageReplyMarkup",
      chat_id: chat_id,
      message_id: message_id,
      reply_markup:
        {:json,
         %{
           inline_keyboard: inline_keyboard
         }}
    )
  end

  @impl true
  def edit_message_text(token, chat_id, message_id, text) do
    Telegram.Api.request(token, "editMessageText",
      chat_id: chat_id,
      parse_mode: "MarkdownV2",
      message_id: message_id,
      disable_web_page_preview: true,
      text: text |> escape_text()
    )
  end

  @impl true
  def send_message(token, chat_id, text, inline_keyboard) do
    Telegram.Api.request(token, "sendMessage",
      chat_id: chat_id,
      parse_mode: "MarkdownV2",
      text: text |> escape_text(),
      reply_markup: {:json, %{inline_keyboard: inline_keyboard}}
    )
  end

  @impl true
  def send_file(token, chat_id, file_name, file_content) do
    Telegram.Api.request(token, "sendDocument",
      chat_id: chat_id,
      document: {:file_content, file_content, file_name}
    )
  end

  @doc false
  def escape_text(text) do
    text
    |> String.split("```")
    |> Enum.reduce({[], true}, fn text_token, {new_list, replace?} ->
      if replace? do
        {[text_token |> escapte_text_token() | new_list], false}
      else
        {[text_token | new_list], true}
      end
    end)
    |> then(fn {list, _} -> list end)
    |> Enum.reverse()
    |> Enum.join("```")

    # |> Enum.reduce("", &(&1 <> &2))
  end

  @doc false
  def escapte_text_token(text_token) do
    String.replace(
      text_token,
      ["-", "~", ",", ">", "#", "+", "=", "{", "}", ".", "!"],
      &"\\#{&1}"
    )
  end
end
