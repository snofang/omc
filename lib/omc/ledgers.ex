defmodule Omc.Ledgers do
  alias Omc.Repo
  alias Omc.Ledgers.{Ledger}
  import Ecto.Query

  def get_ledger(user_type, user_id) do
    Ledger
    |> where(user_type: ^user_type, user_id: ^user_id)
    |> Repo.one()
  end

  def create_ledger(attrs) do
    %Ledger{}
    |> Ledger.create_changeset(attrs, credit: 0)
    |> Repo.insert()
  end
  
  def update_ledger(ledger, attrs) do
    ledger
    |> Ledger.update_changeset(attrs)
    |> Repo.update()
  end
end
