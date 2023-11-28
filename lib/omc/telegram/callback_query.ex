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
              callback_args :: [binary()]
            ) :: {:ok, :done} | {:error, term()}
      def handle(token, callback_query_id, chat_id, message_id, callback_args) do
        try do
          args = %{
            user: %{user_type: :telegram, user_id: chat_id |> to_string()},
            callback_args: if(callback_args, do: callback_args |> String.split("_"), else: nil),
            token: token,
            chat_id: chat_id,
            message_id: message_id
          }

          case do_process(args) do
            {:ok, message, args} ->
              {:ok, _} =
                TelegramApi.edit_message_text(
                  token,
                  chat_id,
                  message_id,
                  get_text(args)
                )

              TelegramApi.edit_message_markup(
                token,
                chat_id,
                message_id,
                get_markup(args)
              )

              TelegramApi.answer_callback(token, callback_query_id, message)

            {:error, message} ->
              TelegramApi.answer_callback(token, callback_query_id, message)
          end

          {:ok, :done}
        rescue
          error ->
            TelegramApi.answer_callback(token, callback_query_id, "Oops!")
            {:error, error}
        end
      end

      @impl true
      def do_process(args) do
        case :erlang.phash2(1, 1) do
          0 ->
            {:ok, nil, args}

          1 ->
            {:error, "should not happen!"}
        end
      end

      @spec markup_item(text :: binary(), callback_data :: binary()) :: map()
      def markup_item(text, callback_data) do
        %{text: text, callback_data: callback_data}
      end

      defoverridable do_process: 1
    end
  end

  @callback do_process(args :: map()) ::
              {:ok, success_message :: binary(), data :: map()}
              | {:error, error_message :: binary()}
  @callback get_text(args :: map()) :: binary()
  @callback get_markup(args :: map()) :: [[map()]]
end
