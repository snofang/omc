defmodule Omc.Telegram.CallbackAccounts do
  alias Omc.Usages
  alias Omc.Servers.PricePlan
  use Omc.Telegram.CallbackQuery
  alias Omc.ServerAccUsers

  @impl true
  def do_process(args = %{user: user, callback_args: callback_args}) do
    case callback_args do
      [tag | [price_plan_id]] ->
        IO.puts("tag: #{tag}, price_plan_id: #{price_plan_id}")

        case Usages.start_usage(user, server_tag: tag, price_plan_id: price_plan_id) do
          {:ok, _} ->
            {:ok, "New account created successfully.", fill_args(args)}

          {:error, error} ->
            {:error, "Failed account creation: #{error}"}
        end

      [] ->
        {:ok, "", fill_args(args)}
    end
  end

  @impl true
  def get_text(%{user: _user, callback_args: _callback_args, accs: accs}) do
    ~s"""
    __*Your Account\\(s\\).*__

    #{if accs |> length() > 0 do
      "By selecting each active account represented in the following buttons, you can manage them, download their .ovpn file, or see usages."
    else
      "No active account! Use one of __*\\(+\\)*__ botton\\(s\\) below to create one. Note that you should have enough credit to do so."
    end}
    """
  end

  @impl true
  def get_markup(%{accs: accs, servers: servers}) do
    servers_markup(servers) ++
      accs_markup(accs) ++
      [[markup_item("<< back", "Main"), markup_item("Create New Account", "accounts-new")]]
  end

  defp servers_markup(servers) do
    TelegramUtils.entities_markup(
      "accounts",
      servers,
      &server_markup_text_provider/1,
      &server_markup_params_provider/1
    )
  end

  defp server_markup_params_provider(%{
         tag: tag,
         price_plan: %PricePlan{} = price_plan,
         count: _count
       }) do
    [tag, price_plan.id |> to_string()]
  end

  defp server_markup_text_provider(%{
         tag: tag,
         price_plan: %PricePlan{} = price_plan,
         count: _count
       }) do
    "+ #{tag} (#{(price_plan.duration / (24 * 60 * 60)) |> round()} Days, #{price_plan.prices |> List.first() |> Money.to_string()})"
  end

  defp accs_markup(accs) do
    TelegramUtils.entities_markup(
      "account",
      accs,
      &acc_markup_text_provider/1,
      &acc_markup_params_provider/1
    )
  end

  defp acc_markup_params_provider(%{
         sa_id: sa_id,
         sa_name: _sa_name,
         sau_id: sau_id
       }) do
    ["account", sa_id |> to_string(), sau_id |> to_string()]
  end

  def acc_markup_text_provider(%{
        sa_id: _sa_id,
        sa_name: sa_name,
        sau_id: _sau_id
      }) do
    "Account - #{sa_name}"
  end

  defp fill_args(args = %{user: user}) do
    args
    |> Map.put(:accs, ServerAccUsers.get_server_accs_in_use(user))
    |> Map.put(:servers, ServerAccUsers.list_server_tags_with_free_accs_count())
  end
end
