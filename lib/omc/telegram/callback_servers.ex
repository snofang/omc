defmodule Omc.Telegram.CallbackServers do
  alias Omc.Usages
  alias Omc.Servers.PricePlan
  use Omc.Telegram.CallbackQuery
  alias Omc.ServerAccUsers
  import Omc.Gettext

  @impl true
  def do_process(args = %{user: user, callback_args: callback_args}) do
    case callback_args do
      [tag | [price_plan_id]] ->
        case Usages.start_usage(user, server_tag: tag, price_plan_id: price_plan_id) do
          {:ok, _} ->
            {:redirect, "Accounts",
             args |> Map.put(:message, gettext("New account created successfully."))}

          {:error, error} ->
            {:error,
             args
             |> Map.put(
               :message,
               dgettext("errors", "Failed account creation:") <> inspect(error)
             )}
        end

      [] ->
        {:ok,
         args
         |> Map.put(:servers, ServerAccUsers.list_server_tags_with_free_accs_count())
         |> Map.put(:message, "")}
    end
  end

  @impl true
  def get_text(%{servers: servers}) do
    ~s"""
    __*#{gettext("New Account Creation")}*__

    #{if servers |> length() > 0 do
      """
      #{gettext("Use one of __*+*__ bottons below to create an account based on your __destination__ needs.")}
      #{gettext("Note that you should have enough credit to do so.")}
      """
    else
      """
      #{gettext("Unfortunately no free account is available right now.")}
      #{gettext("Please come back later and check it again; It will be supplied ASAP.")}
      """
    end}
    """
  end

  @impl true
  def get_markup(%{servers: servers}) do
    servers_markup(servers) ++
      [[markup_item(gettext("Home"), "Main")]]
  end

  defp servers_markup(servers) do
    TelegramUtils.entities_markup(
      "Servers",
      servers,
      &server_markup_text_provider/1,
      &server_markup_params_provider/1,
      true
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
    "+ #{Gettext.gettext(Omc.Gettext, tag)} (#{PricePlan.to_string_duration_days_no_name(price_plan)})"
  end
end
