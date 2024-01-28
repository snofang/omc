defmodule Omc.TelegramBot do
  alias Omc.Telegram.TelegramUtils
  alias Omc.Telegram.TelegramApi
  alias Omc.Telegram.CallbackMain
  alias Omc.Users
  use Telegram.Bot

  @impl Telegram.Bot
  def handle_update(update, token) do
    # TODO: performance issue; to find a place such as init for this
    Gettext.put_locale(Application.get_env(:omc, :telegram)[:locale])

    try do
      case update do
        %{"message" => %{"text" => text, "chat" => %{"id" => chat_id}, "from" => from_data}} ->
          if String.match?(text, ~r/start/) do
            {:ok, _} = from_data |> to_user_info_attrs() |> Users.upsert_user_info()

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
            "from" => from_data,
            "message" => %{"message_id" => message_id, "chat" => %{"id" => chat_id}}
          }
        } ->
          {callback, args} = data |> TelegramUtils.decode_callback_data()

          {:ok, _} =
            TelegramUtils.handle_callback(
              callback,
              %{
                token: token,
                callback_query_id: callback_query_id,
                chat_id: chat_id,
                message_id: message_id,
                callback_args: args,
                user: to_user_info_attrs(from_data)
              }
            )

        _ ->
          Logger.debug("Unknown message:\n\n```\n#{inspect(update, pretty: true)}\n```")
      end
    rescue
      error ->
        if(update["callback_query"]["message"]["chat"]["id"]) do
          TelegramApi.send_message(
            token,
            update["callback_query"]["message"]["chat"]["id"],
            "Sorry! Some problem happened.\nPlease try /start again.",
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

  defp to_user_info_attrs(from_data = %{"id" => user_id}) do
    %{user_type: :telegram, user_id: user_id |> to_string()}
    |> then(fn attrs ->
      if from_data["username"],
        do: attrs |> Map.put(:user_name, from_data["username"]),
        else: attrs
    end)
    |> then(fn attrs ->
      if from_data["first_name"],
        do: attrs |> Map.put(:first_name, from_data["first_name"]),
        else: attrs
    end)
    |> then(fn attrs ->
      if from_data["last_name"],
        do: attrs |> Map.put(:last_name, from_data["last_name"]),
        else: attrs
    end)
    |> then(fn attrs ->
      if from_data["language_code"],
        do: attrs |> Map.put(:language_code, from_data["language_code"]),
        else: attrs
    end)
  end
end
