defmodule Omc.LedgersFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Omc.Ledgers` context.
  """
  alias Omc.Ledgers
  alias Omc.UsersFixtures

  def unique_user_id, do: UsersFixtures.unique_user_id()

  def unique_user_attrs, do: UsersFixtures.unique_user_attrs()

  def valid_ledger_tx_attrubutes(attrs \\ %{}) do
    Enum.into(attrs, %{
      user_type: :telegram,
      user_id: unique_user_id(),
      context: :manual,
      context_id: nil,
      money: Money.new(100),
      type: :credit
    })
  end

  def ledger_tx_fixture!(attrs \\ %{}) do
    Ledgers.create_ledger_tx!(valid_ledger_tx_attrubutes(attrs))
  end
end
