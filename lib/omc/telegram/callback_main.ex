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
        %{text: "Create New Account", callback_data: "order_acc"},
        %{text: "Billing & Credit", callback_data: "Usage"}
      ],
      [
        %{text: "Existing Accounts", callback_data: "my_accs"},
        %{text: "Help", callback_data: "help"}
      ]
    ]
  end
end
