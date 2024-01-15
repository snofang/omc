defmodule Omc.Common.Currency do
  use Ecto.Type
  def type, do: :string

  def cast(term) when is_binary(term) do
    term
    |> String.to_existing_atom()
    |> supported_curerncy()
    |> case do
      true ->
        {:ok, String.to_existing_atom(term)}

      _ ->
        :error
    end
  end

  def cast(term) when is_atom(term) do
    term
    |> supported_curerncy()
    |> case do
      true ->
        {:ok, term}

      _ ->
        :error
    end
  end

  def cast(_), do: :error

  def load(term) when is_binary(term) do
    {:ok, String.to_existing_atom(term)}
  end

  def dump(term) when is_atom(term) do
    term
    |> supported_curerncy()
    |> case do
      true ->
        {:ok, term |> to_string()}

      _ ->
        :error
    end
  end

  def dump(_), do: :error

  def supported_curerncy(currency) when is_atom(currency) do
    currency in Application.get_env(:omc, :supported_currencies)
  end
end
