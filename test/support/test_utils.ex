defmodule Omc.TestUtils do
  def happend_now_or_a_second_later(naive_datetime) do
    happend_closely(NaiveDateTime.utc_now(), naive_datetime)
  end

  def happend_closely(naive_datatime1, naive_datetime2, duration_allowance \\ 1) do
    naive_datatime1
    |> NaiveDateTime.diff(naive_datetime2)
    |> then(&(abs(&1) <= duration_allowance))
  end
end
