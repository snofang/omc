defmodule Omc.TestUtils do
  def happend_now_or_a_second_later(naive_datetime) do
    NaiveDateTime.utc_now()
    |> NaiveDateTime.diff(naive_datetime)
    |> then(&(&1 >= 0 and &1 <= 1))
  end
end
