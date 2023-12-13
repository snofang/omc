defmodule Omc.Telegram.CallbackQuery do
  alias Omc.Telegram.TelegramUtils

  defmacro __using__(_args) do
    quote do
      @behaviour Omc.Telegram.CallbackQuery
      alias Omc.Telegram.TelegramApi
      alias Omc.Telegram.TelegramUtils
      alias TableRex.Table
      require Logger

      @spec handle(%{
              token: binary(),
              callback_query_id: binary(),
              chat_id: binary(),
              message_id: integer(),
              callback_args: [binary()]
            }) :: {:ok, :done} | {:error, term()}
      def handle(
            args = %{
              token: token,
              callback_query_id: callback_query_id,
              chat_id: chat_id,
              message_id: message_id,
              callback_args: callback_args
            }
          ) do
        try do
          case do_process(args) do
            {:redirect, callback, args} ->
              TelegramUtils.handle_callback(callback, args)

            {:ok, args} ->
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

              TelegramApi.answer_callback(token, callback_query_id, args[:message])

            {:error, %{message: message}} ->
              TelegramApi.answer_callback(token, callback_query_id, message)
          end

          {:ok, :done}
        rescue
          error ->
            Logger.error(Exception.format(:error, error, __STACKTRACE__))
            TelegramApi.answer_callback(token, callback_query_id, "Oops!")
            {:error, error}
        end
      end

      @impl true
      def do_process(args) do
        case :erlang.phash2(1, 1) do
          0 ->
            {:ok, args |> Map.put(:message, "")}

          1 ->
            {:error, %{message: "should not happen!"}}

          2 ->
            {:redirect, "no_where", %{message: "should not happen!"}}
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
              {:ok, args :: map()}
              | {:redirect, callback :: binary(), args :: map()}
              | {:error, args :: map()}
  @callback get_text(args :: map()) :: binary()
  @callback get_markup(args :: map()) :: [[map()]]
end
