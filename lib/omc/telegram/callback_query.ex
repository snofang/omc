defmodule Omc.Telegram.CallbackQuery do
  defmacro __using__(_args) do
    quote do
      @behaviour Omc.Telegram.CallbackQuery
      alias Omc.Telegram.TelegramApi
      alias Omc.Telegram.TelegramUtils
      alias TableRex.Table

      @spec handle(
              token :: binary(),
              callback_query_id :: binary(),
              chat_id :: binary(),
              message_id :: integer(),
              data_args :: [binary()]
            ) :: {:ok, :done} | {:error, term()}
      def handle(token, callback_query_id, chat_id, message_id, data_args) do
        try do
          args = %{
            user: %{user_type: :telegram, user_id: chat_id |> to_string()},
            data_args: if(data_args, do: data_args |> String.split("_"), else: nil),
            token: token,
            chat_id: chat_id,
            message_id: message_id
          }

          {:ok, _} = TelegramApi.edit_message_text(token, chat_id, message_id, get_text(args))

          TelegramApi.edit_message_markup(
            token,
            chat_id,
            message_id,
            get_markup(args)
          )

          TelegramApi.answer_callback(token, callback_query_id, "Succeeded!")
          {:ok, :done}
        rescue
          error ->
            TelegramApi.answer_callback(token, callback_query_id, "Oops!")
            {:error, error}
        end
      end

      @spec markup_item(text :: binary(), callback_data :: binary()) :: map()
      def markup_item(text, callback_data) do
        %{text: text, callback_data: callback_data}
      end
    end
  end

  @callback get_text(args :: map()) :: binary()
  @callback get_markup(args :: map()) :: [[map()]]
end
