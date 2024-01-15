defmodule Omc.Ledgers.Ledger do
  use Ecto.Schema
  import Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          user_type: atom(),
          user_id: binary(),
          user_data: map(),
          currency: atom(),
          credit: integer(),
          description: binary(),
          user_info: binary()
        }

  schema "ledgers" do
    field(:user_type, Ecto.Enum, values: [:local, :telegram])
    field(:user_id, :string)
    field(:user_data, :map, default: %{})
    field(:currency, Omc.Common.Currency)
    field(:credit, :integer, default: 0)
    field(:description, :string)
    field(:lock_version, :integer, default: 1)
    field(:user_info, :string, virtual: true)
    timestamps()
    # has_many :ledger_txs, Omc.Ledgers.LedgerTx
    # has_many :ledger_accs, Omc.Ledgers.LedgerAcc
  end

  def create_changeset(ledger, attrs) do
    ledger
    |> cast(attrs, [:user_type, :user_id, :currency, :credit])
    |> validate_required([:user_type, :user_id, :currency, :credit])
  end

  def update_changeset(ledger, %{type: type, amount: amount}) when amount > 0 do
    case type do
      :credit ->
        __update_changeset(ledger, %{credit: ledger.credit + amount})

      :debit ->
        __update_changeset(ledger, %{credit: ledger.credit - amount})
    end
  end

  defp __update_changeset(ledger, attrs) do
    ledger
    |> cast(attrs, [:credit])
    |> validate_required([:credit])
    |> optimistic_lock(:lock_version)
    |> case do
      %{changes: %{credit: _}} = changeset -> changeset
      %{} = changeset -> add_error(changeset, :credit, "did not change")
    end
  end

  @doc """
  Returns credit value in `Money`.
  """
  @spec credit_money(__MODULE__.t()) :: Money.t()
  def credit_money(%__MODULE__{} = ledger) do
    Money.new(ledger.credit, ledger.currency)
  end

  def user_attrs(%__MODULE__{} = ledger) do
    %{user_type: ledger.user_type, user_id: ledger.user_id}
  end
end
