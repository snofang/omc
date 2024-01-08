defmodule Omc.Telegram.CallbackAccounts do
  use Omc.Telegram.CallbackQuery
  alias Omc.ServerAccUsers

  @impl true
  def do_process(args = %{user: user, callback_args: callback_args}) do
    case callback_args do
      ["some imposible arg1"] ->
        {:redirect, "Main", %{message: "dialyzer trick"}}

      ["some imposible arg2"] ->
        {:error, %{message: "dialyzer trick"}}

      # doesn't matter which callback_args are comming for each of redirection.
      _ ->
        {:ok,
         args
         |> Map.put(:accs, ServerAccUsers.get_server_accs_in_use(user))
         |> Map.put_new(:message, "")}
    end
  end

  @impl true
  def get_text(%{user: _user, callback_args: _callback_args, accs: accs}) do
    ~s"""
    __*Your Account\\(s\\).*__

    #{if accs |> length() > 0 do
      "By selecting each account represented by each of the following buttons by account name, you can manage it, download connection config __.ovpn__ file, or see its __usages__."
    else
      "No active account!"
    end}
    """
  end

  @impl true
  def get_markup(%{accs: accs}) do
    accs_markup(accs) ++
      [[markup_item("<< back", "Main"), markup_item("Refresh", "Accounts")]]
  end

  defp accs_markup(accs) do
    TelegramUtils.entities_markup(
      "Account",
      accs,
      &acc_markup_text_provider/1,
      &acc_markup_params_provider/1
    )
  end

  defp acc_markup_params_provider(%{
         sa_id: sa_id,
         sa_name: sa_name,
         sau_id: sau_id
       }) do
    [sa_id |> to_string(), sa_name, sau_id |> to_string()]
  end

  def acc_markup_text_provider(%{
        sa_id: _sa_id,
        sa_name: sa_name,
        sau_id: _sau_id
      }) do
    "#{sa_name}"
  end
end
