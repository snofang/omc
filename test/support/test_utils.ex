defmodule Omc.TestUtils do
  def happend_now_or_a_second_later(naive_datetime) do
    happend_closely(NaiveDateTime.utc_now(), naive_datetime)
  end

  def happend_closely(nil, nil) do
    true
  end

  def happend_closely(naive_datatime1, naive_datetime2, duration_allowance \\ 1) do
    naive_datatime1
    |> NaiveDateTime.diff(naive_datetime2)
    |> then(&(abs(&1) <= duration_allowance))
  end

  def eventual_assert(func, max_time \\ 2000) do
    if max_time <= 0, do: raise("times up; assertion failed.")

    unless func.() do
      Process.sleep(50)
      eventual_assert(func, max_time - 50)
    end
  end

  # def eventual_match(func, max_time \\ 2000) do
  #   if max_time <= 0, do: raise("times up; match failed.")
  #
  #   try do
  #     func.()
  #   rescue
  #     MatchError ->
  #       Process.sleep(50)
  #       eventual_match(func, max_time - 50)
  #   end
  # end
end
