defmodule Omc.Telegram.CallbackAccount do
  use Omc.Telegram.CallbackQuery
  alias Omc.Usages

  @impl true
  def do_process(args = %{callback_args: callback_args}) do
    case callback_args do
      [_sa_id | [_sa_name | [sau_id]]] ->
        {:ok,
         args
         |> Map.put(:usage_line_items, Usages.get_acc_usages_line_items(sau_id))
         |> Map.put_new(:message, "")}

      [] ->
        {:error, args |> Map.put(:message, "acc not specified")}

      _ ->
        {:redirect, "main", args |> Map.put(:message, "Bad args; redirected")}
    end
  end

  @impl true
  def get_text(%{
        callback_args: [_sa_id | [sa_name | [_sau_id]]],
        usage_line_items: usage_line_items
      }) do
    ~s"""
    *Account __#{sa_name}__ Usages:*

    #{usage_line_items |> usage_line_items_text()}
    """
  end

  @impl true
  def get_markup(%{}) do
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
