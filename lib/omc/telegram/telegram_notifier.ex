defmodule Omc.Telegram.TelegramNotifier do
  alias Phoenix.PubSub
  alias Omc.Telegram.TelegramApi
  use GenServer
  import Omc.Gettext

  def start_link(_args) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_init_arg) do
    Gettext.put_locale(Application.get_env(:omc, :telegram)[:locale])
    PubSub.subscribe(Omc.PubSub, "usages")
    {:ok, %{token: Application.get_env(:omc, :telegram)[:token]}}
  end

  def handle_cast(
        {:send_message, chat_id, message},
        state = %{token: token}
      ) do
    TelegramApi.send_message(
      token,
      chat_id,
      message
    )

    {:noreply, state}
  end

  def handle_info(
        {:usage_duration_margin_notify, %{user_type: :telegram, user_id: user_id}},
        state
      ) do
    GenServer.cast(
      __MODULE__,
      {:send_message, user_id,
       gettext(
         "Your credit balance is running low. To avoid any disruptions, please consider topping up soon."
       )}
    )

    {:noreply, state}
  end
end
