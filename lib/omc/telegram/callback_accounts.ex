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
    __*Your Account\\(s\\)*__

    #{if accs |> length() > 0 do
      "By tapping on each account represented by the following buttons, you can manage it, download its connection config __.ovpn__ file, or see its __usages__."
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

  defp acc_markup_params_provider(%{s_id: s_id, sa_id: sa_id, sau_id: sau_id, s_tag: s_tag}) do
    [s_id, sa_id, sau_id, s_tag]
  end

  def acc_markup_text_provider(%{s_id: _s_id, sa_id: sa_id, sau_id: _sau_id, s_tag: s_tag}) do
    TelegramUtils.sa_name(sa_id, s_tag)
  end
end
