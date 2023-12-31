defmodule Omc.Telegram.CallbackAccount do
  use Omc.Telegram.CallbackQuery
  alias Omc.Usages
  alias Omc.Servers.ServerOps
  alias Omc.Servers
  alias Omc.Telegram.TelegramUtils

  @impl true
  def do_process(args = %{callback_args: callback_args}) do
    case callback_args do
      [_sa_id, _sa_name, _sau_id | _actions] ->
        process(args)

      [] ->
        {:error, args |> Map.put(:message, "acc not specified")}

      _ ->
        {:redirect, "main", args |> Map.put(:message, "Bad args; redirected")}
    end
  end

  defp process(args = %{callback_args: [sa_id, _sa_name, sau_id]}) do
    {:ok,
     args
     |> Map.put(:usage_line_items, Usages.get_acc_usages_line_items(sau_id))
     |> Map.put(:server_acc, Servers.get_server_acc!(sa_id))
     |> Map.put_new(:message, "")}
  end

  defp process(%{
         token: token,
         chat_id: chat_id,
         callback_args: [sa_id, _sa_name, _sau_id | ["file"]]
       }) do
    sa = Servers.get_server_acc!(sa_id)

    case ServerOps.acc_file_path(sa) |> File.read() do
      {:ok, content} ->
        case TelegramApi.send_file(token, chat_id, sa.name <> ".ovpn", content) do
          {:ok, _} ->
            # trick to stop further text and markup update
            {:error, %{message: "File sent successfully."}}

          {:error, file_send_error} ->
            Logger.error("Sending file failed; error: #{inspect(file_send_error)}")
            {:error, %{message: "Something wrong with file sending process."}}
        end

      {:error, _} ->
        {:error, %{message: "Failed! File not found!"}}
    end
  end

  @impl true
  def get_text(%{
        callback_args: [_sa_id, _sa_name, _sau_id | _action],
        server_acc: server_acc,
        usage_line_items: usage_line_items
      }) do
    ~s"""
    __*Account _#{server_acc.name}_ Info:*__

    *Status:**_ __#{server_acc.status |> Atom.to_string() |> TelegramUtils.escape_text() |> String.capitalize()}___*

    *Usages List:*
    _Note: All date & time values are in UTC._
    #{usage_line_items |> usage_line_items_text()}
    """
  end

  @impl true
  def get_markup(args = %{callback_args: callback_args}) do
    [
      [
        markup_item(
          ".ovpn file",
          TelegramUtils.encode_callback_data("Account", callback_args ++ ["file"])
        )
      ] ++ get_markup_delete(args)
    ] ++
      [[markup_item("<< Accounts", "Accounts"), markup_item("Main", "Main")]]
  end

  defp get_markup_delete(%{callback_args: callback_args, server_acc: server_acc}) do
    case server_acc.status do
      :active ->
        [
          markup_item(
            "Delete",
            TelegramUtils.encode_callback_data("AccountDelete", callback_args)
          )
        ]

      _ ->
        []
    end
  end

  defp usage_line_items_text(usage_line_items) do
    usage_line_items
    |> Enum.reduce(nil, fn uli, result ->
      if(result, do: result <> "\n", else: "")
      |> then(&(&1 <> usage_line_item_text(uli)))
    end)
  end

  defp usage_line_item_text(%{
         started_at: started_at,
         ended_at: ended_at,
         amount: amount,
         currency: currency
       }) do
    "- *from:* __#{started_at}__," <>
      " *to:* __#{ended_at}__," <>
      " *usage:* __#{Money.new(amount, currency)}__ "
  end
end
