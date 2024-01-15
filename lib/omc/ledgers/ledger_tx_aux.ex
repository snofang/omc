defmodule Omc.Ledgers.LedgerTxAux do
  @moduledoc """
  Helps creating ledgerTx entries.
  """
  use Ecto.Schema
  import Ecto.Schema
  import Ecto.Changeset
  alias Omc.Ledgers.{Ledger, LedgerTx}

  embedded_schema do
    field(:user_type, Ecto.Enum, values: Ecto.Enum.values(Ledger, :user_type))
    field(:user_id, :string)
    field(:type, Ecto.Enum, values: Ecto.Enum.values(LedgerTx, :type))
    field(:currency, Omc.Common.Currency)
    field(:amount, :string)
  end

  def changeset(data, attrs \\ %{}) do
    data
    |> cast(attrs, [
      :user_type,
      :user_id,
      :type,
      :currency,
      :amount
    ])
    |> validate_required([:user_type, :user_id, :type, :currency, :amount])
    |> validate_format(:amount, ~r/^\d*(\.\d{1,2})?$/)

    # |> validate_amount()
  end

  # defp validate_amount(changeset) do
  #   changeset
  #   |> validate_change(:amount, fn :amount, amount ->
  #     case changeset |> Ecto.Changeset.apply_changes() |> then(& &1.currency) do
  #       nil ->
  #         [amount: "Currency should be specified"]
  #
  #       currency ->
  #         case Money.parse(amount, currency) do
  #           {:ok, _money} ->
  #               []
  #
  #           :error ->
  #             [amount: "Invalid format"]
  #         end
  #     end
  #   end)
  # end
end
