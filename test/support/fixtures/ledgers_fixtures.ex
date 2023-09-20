defmodule Omc.LedgersFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Omc.Ledgers` context.
  """
  def unique_user_id do
    (0xF000000000000000 + System.unique_integer([:positive, :monotonic]))
    |> Integer.to_string()
  end

  def valid_ledger_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      user_id: unique_user_id(),
      user_type: :telegram,
      credit: 0,
      description: "some description"
    })
  end

  def ledger_fixture(attrs \\ %{}) do
    {:ok, ledger} = valid_ledger_attributes(attrs)
    |> Omc.Ledgers.create_ledger()
    ledger
  end
end
