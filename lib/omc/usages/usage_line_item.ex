defmodule Omc.Usages.UsageLineItem do
  @moduledoc """
  To aid in listing `UsaageItems`s accompanied with amount of credit they used.
  """
  defstruct [:usage_item_id, :started_at, :ended_at, :amount, :currency]
  alias Omc.Usages.{Usage, UsageState}

  @doc """
  Transform `UsageState` to list of equivalent `UsageLineItem`s.
  """
  @spec usage_state_usage_line_items(%UsageState{}) :: [%__MODULE__{}]
  def usage_state_usage_line_items(%UsageState{} = usage_state) do
    usage_state.usages
    |> Enum.reduce([], fn u, result ->
      result ++
        usage_state_usage_line_item(
          u,
          usage_changesets(u, usage_state.changesets),
          usage_state.ledgers
        )
    end)
  end

  defp usage_state_usage_line_item(%Usage{} = usage, [], ledgers) do
    [
      %__MODULE__{
        usage_item_id: -1,
        started_at: usage.started_at,
        ended_at: Omc.Common.Utils.now(),
        amount: 0,
        currency: get_in(ledgers, [Access.at(0), Access.key(:currency)])
      }
    ]
  end

  defp usage_state_usage_line_item(%Usage{} = _usage, changesets, ledgers) do
    changesets
    |> Enum.reduce([], fn %{
                            ledger_tx_changeset: %{
                              changes: %{amount: amount, ledger_id: ledger_id}
                            },
                            usage_item_changeset: %{
                              changes: %{started_at: started_at, ended_at: ended_at}
                            }
                          },
                          result ->
      result ++
        [
          %__MODULE__{
            usage_item_id: -1,
            started_at: started_at,
            ended_at: ended_at,
            amount: amount,
            currency: ledger_currency(ledgers, ledger_id)
          }
        ]
    end)
  end

  defp usage_changesets(usage, changesets) do
    changesets
    |> Enum.filter(fn %{usage_item_changeset: %{changes: %{usage_id: usage_id}}} ->
      usage_id == usage.id
    end)
  end

  defp ledger_currency(ledgers, ledger_id) do
    ledgers
    |> Enum.find(&(&1.id == ledger_id))
    |> then(& &1.currency)
  end
end
