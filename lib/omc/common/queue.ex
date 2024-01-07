defmodule Omc.Common.Queue do
  defstruct value: nil, r_items: [], items: []

  def new() do
    %__MODULE__{}
  end

  def push(%__MODULE__{value: value, r_items: r_items, items: items}, item)
      when not is_nil(item) do
    %__MODULE__{value: value, r_items: r_items, items: [item | items]}
  end

  def pop(%__MODULE__{value: _, r_items: [h | t], items: items}) do
    %__MODULE__{value: h, r_items: t, items: items}
  end

  def pop(%__MODULE__{value: _, r_items: [], items: []}) do
    %__MODULE__{value: nil, r_items: [], items: []}
  end

  def pop(%__MODULE__{value: _, r_items: [], items: items}) do
    [h | t] = Enum.reverse(items)
    %__MODULE__{value: h, r_items: t, items: []}
  end

  def peek(%__MODULE__{value: _, r_items: [h | t], items: items}) do
    %__MODULE__{value: h, r_items: [h | t], items: items}
  end

  def peek(%__MODULE__{value: _, r_items: [], items: []}) do
    %__MODULE__{value: nil, r_items: [], items: []}
  end

  def peek(%__MODULE__{value: _, r_items: [], items: items}) do
    [h | t] = Enum.reverse(items)
    %__MODULE__{value: h, r_items: [h | t], items: []}
  end

  def value(%__MODULE__{value: value}) do
    value
  end

  def to_list(%__MODULE__{} = q) do
    pop_add_to_list(q, [])
  end

  defp pop_add_to_list(%__MODULE__{} = q, list) do
    case(q |> pop()) do
      %{value: nil} ->
        list

      q = %{value: value} ->
        pop_add_to_list(q, [value | list])
    end
  end
end
