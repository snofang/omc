defmodule Omc.Telegram.CallbackMain do
  use Omc.Telegram.CallbackQuery
  import Omc.Gettext

  @impl true
  def get_text(_args) do
    ~s"""
    __*#{gettext("Welcome!")}*__ 

    #{gettext("From here, you can create accounts, manage them, and see your credit and usages in detail.")}
    #{gettext("To start, increase your __credit__ and then use that credit to create __new accounts__. Enjoy!")}
    """
  end

  @impl true
  def get_markup(_args) do
    [
      [
        %{text: gettext("New Account"), callback_data: "Servers"},
        %{text: gettext("Credit"), callback_data: "Credit"}
      ],
      [
        %{text: gettext("Accounts"), callback_data: "Accounts"},
        %{text: gettext("Help"), callback_data: "Help"}
      ]
    ]
  end
end
