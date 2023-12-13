defmodule Omc.Users do
  alias Omc.Users.UserInfo
  alias Omc.Repo
  alias Omc.Users.UserInfo
  import Ecto.Query

  @doc """
  Inserts or updates `UserInfo`
  Note: Among fields of `attrs`, `user_type` and `user_id` are required.
  """
  def upsert_user_info(attrs = %{user_id: _, user_type: _}) do
    (get_user_info(attrs) || %UserInfo{})
    |> UserInfo.changeset(attrs)
    |> Repo.insert_or_update()
  end

  def get_user_info(%{user_type: user_type, user_id: user_id}) do
    UserInfo
    |> where([u], u.user_type == ^user_type and u.user_id == ^user_id)
    |> Repo.one()
  end
end
