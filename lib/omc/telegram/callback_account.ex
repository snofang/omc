defmodule Omc.Telegram.CallbackAccount do
  alias Omc.Usages.Usage
  use Omc.Telegram.CallbackQuery
  alias Omc.Usages

  @impl true
  def do_process(args = %{callback_args: callback_args}) do
    case callback_args do
      [_sa_id | [_sa_name | [sau_id]]] ->
        {:ok,
         args
         |> Map.put(:usage_state, Usages.get_acc_usage_state(sau_id))
         |> Map.put_new(:message, "")}

      [] ->
        {:error, args |> Map.put(:message, "acc not specified")}

      _ ->
        {:redirect, "main", args |> Map.put(:message, "Bad args; redirected")}
    end
  end

  @impl true
  def get_text(%{callback_args: [_sa_id | [sa_name | [_sau_id]]], usage_state: us}) do
    ~s"""
    *Account __#{sa_name}__ Usages:*

    #{us.usages |> Enum.map(fn u -> usage_text(u, usage_changesets(u, us.changesets), us.ledgers) end)}
    """
  end

  defp usage_changesets(usage, changesets) do
    changesets
    |> Enum.filter(fn %{usage_item_changeset: %{changes: %{usage_id: usage_id}}} ->
      usage_id == usage.id
    end)
  end

  alias Omc.Usages

  defp usage_text(%Usage{} = _usage, changesets, ledgers) do
    changesets
    |> Enum.reduce(nil, fn %{
                             ledger_tx_changeset: %{
                               changes: %{amount: amount, ledger_id: ledger_id}
                             },
                             usage_item_changeset: %{
                               changes: %{started_at: started_at, ended_at: ended_at}
                             }
                           },
                           result ->
      result = if result, do: "\n" <> result, else: ""

      result <>
        "- *from:* __#{started_at}__, *to:* __#{ended_at}__, *usage:* __#{Money.new(amount, ledger_currency(ledgers, ledger_id))}__ "
    end)
  end

  defp ledger_currency(ledgers, ledger_id) do
    ledgers
    |> Enum.find(&(&1.id == ledger_id))
    |> then(& &1.currency)
  end

  @impl true
  def get_markup(%{}) do
    [[markup_item("<< Accounts", "accounts"), markup_item("Main", "main")]]
  end
end
