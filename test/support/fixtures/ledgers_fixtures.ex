defmodule Omc.LedgersFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Omc.Ledgers` context.
  """
  alias Omc.Ledgers

  def unique_user_id do
    (0xF000000000000000 + System.unique_integer([:positive, :monotonic]))
    |> Integer.to_string()
  end

  def valid_ledger_tx_attrubutes(attrs \\ %{}) do
    Enum.into(attrs, %{
      user_type: :telegram,
      user_id: unique_user_id(),
      context: :manual,
      money: Money.new(100),
      type: :credit
    })
  end

  def ledger_tx_fixrute(attrs \\ %{}) do
    Ledgers.create_ledger_tx!(valid_ledger_tx_attrubutes(attrs))
  end
end
