defmodule Omc.Common.CmdWrapper do
  @moduledoc """
  To execute given os command and report via callback messages
  as progreses.
  In order to process progress messages, caller should handle messages of
  `{:progress, prompt}` format.
  """
  @callback run(binary(), non_neg_integer, binary(), term()) :: binary()

  def run(cmd, timeout \\ nil, topic, ref), do: impl().run(cmd, timeout, topic, ref)
  defp impl, do: Application.get_env(:omc, :cmd_wrapper)[:impl]
end
