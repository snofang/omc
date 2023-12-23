defmodule Omc.Telegram.CallbackMain do
  use Omc.Telegram.CallbackQuery

  @impl true
  def get_text(_args) do
    ~s"""
    __*Welcome!*__ 

    From here, you can buy account\\(s\\), manage them, and see your credit and billings in detail.
    """
  end

  @impl true
  def get_markup(_args) do
    [
      [
        %{text: "New Account", callback_data: "Servers"},
        %{text: "Credit", callback_data: "Credit"}
      ],
      [
        %{text: "Accounts", callback_data: "Accounts"},
        %{text: "Help", callback_data: "Help"}
      ]
    ]
  end
end
