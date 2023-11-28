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
        %{text: "Account(s)", callback_data: "Account"},
        %{text: "Credit", callback_data: "Credit"}
      ],
      [
        %{text: "Billings", callback_data: "Billing"},
        %{text: "Help", callback_data: "Help"}
      ]
    ]
  end
end
