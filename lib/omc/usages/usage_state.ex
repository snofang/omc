defmodule Omc.Usages.UsageState do
  @moduledoc """
  Holds and expresses the last usage(credits & expenses) state of a `user` 
  for the running(`allocated` and `started`) accounts (`ServerAcc`).
  This includes those records that have already persisted and the new ones. For
  the new ones the corresponding changesets also collected to aid in persisting 
  this state if needed or wanted.
  """
  alias Omc.Ledgers
  alias Omc.Usages.{Usage, UsageItem}
  alias Omc.Ledgers.Ledger
  alias Omc.Servers.PricePlan

  defstruct usages: [],
            ledgers: [],
            changesets: []

  @doc """
  Computes last state of usage in terms of `Omc.Usages.UsageState`.
  """
  def compute(%__MODULE__{} = state, till \\ now()) do
    case first_duration_usage(state.usages, till) do
      nil ->
        state

      usage ->
        case first_oldest_used_ledger(state.ledgers) do
          # No credit, going to make last used ledger's credit negetive
          nil ->
            first_last_used_ledger(state.ledgers)
            |> use_credit(usage, state, :duration, till)
            |> compute(till)

          # Some credit, going to use it.
          ledger ->
            ledger
            |> use_credit(usage, state, :duration, till)
            |> compute(till)
        end
    end
  end

  @doc false
  def use_credit(%Ledger{} = ledger, %Usage{} = usage, %__MODULE__{} = state, :duration, till)
      when ledger.credit > 0 do
    amount = calc_duration_money(usage.price_plan, ledger.currency, usage_start_time(usage), till)

    amount
    |> Money.compare(Money.new(ledger.credit, ledger.currency))
    |> case do
      # usage amount is greater than credit
      1 ->
        start_dt = usage_start_time(usage)

        end_dt =
          start_dt
          |> NaiveDateTime.add(
            calc_money_duration(usage.price_plan, Money.new(ledger.credit, ledger.currency))
          )

        duration_usage_item_attrs(usage.id, start_dt, end_dt)

      # usage amount is less than or equal credit
      _ ->
        duration_usage_item_attrs(usage.id, usage_start_time(usage), till)
    end
    |> then(fn attrs -> add_usage_item(state, ledger.currency, attrs) end)
  end

  @doc false
  # ledger's credit is not positive so going to negate it(or let it be debit)
  def use_credit(%Ledger{} = ledger, %Usage{} = usage, %__MODULE__{} = state, :duration, till) do
    add_usage_item(
      state,
      ledger.currency,
      duration_usage_item_attrs(usage.id, usage_start_time(usage), till)
    )
  end

  defp add_usage_item(
         %__MODULE__{} = state,
         currency,
         %{
           type: :duration,
           usage_id: usage_id,
           started_at: started_at,
           ended_at: ended_at
         } = usage_item_attrs
       ) do
    usage =
      state.usages
      |> Enum.find(&(&1.id == usage_id))

    money =
      calc_duration_money(
        usage.price_plan,
        currency,
        started_at,
        ended_at
      )

    add_and_apply_changesets(state, money, usage_item_attrs)
  end

  def add_and_apply_changesets(
        %__MODULE__{} = state,
        %Money{} = money,
        %{} = usage_item_attrs
      ) do
    state
    |> add_changesets(money, usage_item_attrs)
    |> apply_usage_changeset()
    |> apply_ledger_changeset()
  end

  defp add_changesets(
         %__MODULE__{} = state,
         %Money{amount: amount, currency: currency},
         usage_item_attrs
       )
       when amount > 0 do
    state
    |> add_item(
      :changesets,
      Ledgers.ledger_update_changeset(%{
        ledger: ledger_by_currency(state, currency),
        context: :usage,
        context_id: -1,
        amount: amount,
        type: :debit
      })
      |> Map.put(:usage_item_changeset, UsageItem.create_changeset(usage_item_attrs))
    )
  end

  # money's amount is not positive
  defp add_changesets(
         %__MODULE__{} = state,
         _money,
         usage_item_attrs
       ) do
    state
    |> add_item(:changesets, %{usage_item_changeset: UsageItem.create_changeset(usage_item_attrs)})
  end

  defp apply_usage_changeset(%__MODULE__{} = state) do
    %{usage_item_changeset: changeset} = state.changesets |> List.last()

    state
    |> Map.replace(
      :usages,
      state.usages
      |> Enum.map(fn usage ->
        if usage.id == changeset.changes.usage_id do
          usage
          |> Map.replace(
            :usage_items,
            usage.usage_items ++ [Ecto.Changeset.apply_changes(changeset)]
          )
        else
          usage
        end
      end)
    )
  end

  defp apply_ledger_changeset(%__MODULE__{} = state) do
    state.changesets
    |> List.last()
    |> case do
      nil ->
        state

      changeset ->
        case changeset do
          %{ledger_changeset: ledger_changeset} ->
            state |> apply_changeset(:ledgers, ledger_changeset)

          _ ->
            state
        end
    end
  end

  defp add_item(%__MODULE__{} = state, member, item) do
    state
    |> Map.replace(member, Map.get(state, member) ++ [item])
  end

  defp apply_changeset(%__MODULE__{} = state, _member, nil), do: state

  defp apply_changeset(%__MODULE__{} = state, member, changeset) do
    state
    |> Map.replace(
      member,
      Map.get(state, member)
      |> Enum.map(fn item ->
        if item.id == changeset.data.id do
          Ecto.Changeset.apply_changes(changeset)
          # |> Map.replace(:updated_at, Utils.now())
        else
          item
        end
      end)
    )
  end

  defp ledger_by_currency(%__MODULE__{} = state, currency) do
    state.ledgers
    |> Enum.find(&(&1.currency == currency))
  end

  @doc false
  def calc_duration_money(
        %PricePlan{} = price_plan,
        currency,
        %NaiveDateTime{} = start_dt,
        %NaiveDateTime{} = end_dt
      ) do
    calc_duration_money(
      price_plan,
      currency,
      end_dt
      |> NaiveDateTime.diff(start_dt)
    )
  end

  def calc_duration_money(%PricePlan{} = price_plan, currency, duration_in_seconds)
      when duration_in_seconds >= 0 do
    duration_in_seconds
    |> Decimal.new()
    |> Decimal.mult(
      price_plan.prices
      |> Enum.find(&(&1.currency == currency))
      |> Money.to_decimal()
    )
    |> Decimal.div(price_plan.duration)
    |> Money.parse(currency)
    |> then(fn {:ok, money} -> money end)
  end

  @doc """
  Calculates duration which required to consume `money` in case of given `usage`.
  """
  @spec calc_money_duration(%PricePlan{}, Money.t()) :: integer()
  def calc_money_duration(%PricePlan{} = price_plan, %Money{} = money) do
    price = PricePlan.price(price_plan, money.currency)

    if(money.currency == price.currency) do
      Money.to_decimal(money)
      |> Decimal.mult(price_plan.duration)
      |> Decimal.div(Money.to_decimal(price))
      # TODO: add some test for grabbing this up rounding; ininit looping danger.
      |> Decimal.round(0, :up)
      # |> Decimal.round()
      |> Decimal.to_integer()
    else
      raise "different currencies"
    end
  end

  @doc false
  def first_last_used_ledger(ledgers) do
    ledgers
    |> Enum.filter(&(&1.updated_at != nil))
    |> Enum.sort(&(NaiveDateTime.compare(&1.updated_at, &2.updated_at) == :gt))
    |> List.first()
  end

  @doc false
  def first_duration_usage(usages, till) do
    usages
    |> Enum.filter(fn usage ->
      till
      |> NaiveDateTime.diff(usage_start_time(usage))
      |> Kernel.>(0)
    end)
    |> List.first()
  end

  @doc false
  def usage_start_time(%Usage{} = usage) do
    case usage.usage_items |> List.last() do
      nil ->
        usage.started_at

      last_usage_item ->
        last_usage_item.ended_at
    end
  end

  defp duration_usage_item_attrs(usage_id, start_dt, end_dt) do
    %{
      type: :duration,
      started_at: start_dt,
      ended_at: end_dt,
      usage_id: usage_id
    }
  end

  @doc false
  def price(%Usage{} = usage, currency) do
    usage.price_plan.prices
    |> Enum.find(fn money -> money.currency == currency end)
  end

  @doc false
  defp first_oldest_used_ledger(ledgers) do
    ledgers
    |> Enum.filter(&(&1.updated_at != nil and &1.credit > 0))
    |> Enum.sort(&(NaiveDateTime.compare(&1.updated_at, &2.updated_at) == :lt))
    |> List.first()
  end

  defp now() do
    NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
  end

  def changesets_of_ledger(%__MODULE__{} = state, %{id: ledger_id}) do
    state.changesets
    # Not all changeset group has ledger related changeset. some of them only has just changeset for `UsageItem`
    |> Enum.filter(fn changeset ->
      case changeset do
        %{ledger_changeset: changeset} ->
          changeset.data.id == ledger_id

        _ ->
          false
      end
    end)
  end
end
