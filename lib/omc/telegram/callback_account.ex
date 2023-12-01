defmodule Omc.Telegram.CallbackAccount do
  use Omc.Telegram.CallbackQuery
  alias Omc.ServerAccUsers

  @impl true
  def do_process(args = %{user: user, callback_args: callback_args}) do
    case callback_args do
      ["new"] ->
        {:error, "Not enough credit"}

      nil ->
        {:ok, "",
         args
         |> Map.put(:accs, ServerAccUsers.list_active_accs(user))
         |> Map.put(:servers, ServerAccUsers.list_server_tags_with_free_accs_count())}
    end
  end

  @impl true
  def get_text(%{user: _user, callback_args: _callback_args, accs: accs}) do
    ~s"""
    __*Your Account\\(s\\).*__

    #{if accs |> length() > 0 do
      "By selecting each active account represented in the following buttons, you can manage them, download their .ovpn file, or see usages."
    else
      "No active account! Use __Create New Account__ botton below to start; Before that ensure that you have at least __$1.00__ credit."
    end}
    """
  end

  @impl true
  def get_markup(%{accs: accs, servers: _servers}) do
    accs
    |> active_acc_markup()
    |> then(
      &(&1 ++ [[markup_item("<< back", "Main"), markup_item("Create New Account", "Account-new")]])
    )
  end

  # TODO: It is needed to have a price plan reference, so that it would be possible to let
  # a user to refer to it while creating/buying
  # defp servers_markup(servers) do
  #   servers
  #   |> Enum.reduce([[]], fn %{tag: tag, price_plans: price_plans, count: count}, result ->
  #     case result |> List.first() do
  #       [] ->
  #         [[markup_item(tag, "Account-new_#{sau_id}")]]
  #
  #       [item | []] ->
  #         result
  #         |> List.replace_at(0, [markup_item(sa_name, "usage_#{sau_id}") | [item]])
  #
  #       _ ->
  #         [[markup_item(sa_name, "usage_#{sau_id}")] | result]
  #     end
  #   end)
  # end

  defp active_acc_markup(active_accs) do
    active_accs
    |> Enum.reduce([[]], fn %{sa_name: sa_name, sa_id: _sa_id, sau_id: sau_id}, result ->
      case result |> List.first() do
        [] ->
          [[markup_item(sa_name, "usage_#{sau_id}")]]

        [item | []] ->
          result
          |> List.replace_at(0, [markup_item(sa_name, "usage_#{sau_id}") | [item]])

        _ ->
          [[markup_item(sa_name, "usage_#{sau_id}")] | result]
      end
    end)
  end
end
