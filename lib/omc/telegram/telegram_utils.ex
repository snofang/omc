defmodule Omc.Telegram.TelegramUtils do

  @spec markup_item(text :: binary(), callback_data: binary()) :: map()
  def markup_item(text, callback_data) do
    %{text: text, callback_data: callback_data}
  end

end
