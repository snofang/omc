defmodule Omc.Telegram.CallbackAccount do
  use Omc.Telegram.CallbackQuery
  alias Omc.Usages
  alias Omc.Servers.ServerOps
  alias Omc.Servers

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

  defp process(args = %{callback_args: [_sa_id, _sa_name, sau_id]}) do
    {:ok,
     args
     |> Map.put(:usage_line_items, Usages.get_acc_usages_line_items(sau_id))
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
            {:error, %{message: "File send successfully."}}

          {:error, file_send_error} ->
            Logger.error("Sending file failed; error: #{inspect(file_send_error)}")
            {:error, %{message: "Somthing wrong with file sending process."}}
        end

      {:error, _} ->
        {:error, %{message: "Failed! File not fount!"}}
    end
  end

  @impl true
  def get_text(%{
        callback_args: [_sa_id, sa_name, _sau_id | _action],
        usage_line_items: usage_line_items
      }) do
    ~s"""
    *Account __#{sa_name}__ Usages:*

    #{usage_line_items |> usage_line_items_text()}
    """
  end

  @impl true
  def get_markup(%{callback_args: callback_args}) do
    [
      [
        markup_item(
          ".ovpn file",
          TelegramUtils.encode_callback_data("account", callback_args ++ ["file"])
        ),
        markup_item("Main", "main")
      ]
    ] ++
      [[markup_item("<< Accounts", "accounts"), markup_item("Main", "main")]]
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
