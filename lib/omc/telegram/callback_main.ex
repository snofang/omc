defmodule Omc.Telegram.CallbackMain do
  use Omc.Telegram.CallbackQuery

  @impl true
  def get_text(_args) do
    ~s"""
    *Welcome!* 

    From here, you can buy account\\(s\\), manage them, and see your credit and billings in detail.
    """
  end

  @impl true
  def get_markup(_args) do
    [
      [
        %{text: "New Account", callback_data: "servers"},
        %{text: "Credit", callback_data: "credit"}
      ],
      [
        %{text: "Accounts", callback_data: "accounts"},
        %{text: "Help", callback_data: "help"}
      ]
    ]
  end
end
