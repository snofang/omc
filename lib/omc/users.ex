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

  @doc """
  Fetches a single `UserInfo` by filter args.
  """
  @spec get_user_info(%{user_type: atom(), user_id: binary()}) :: %UserInfo{} | nil
  def get_user_info(%{user_type: user_type, user_id: user_id}) do
    UserInfo
    |> where([u], u.user_type == ^user_type and u.user_id == ^user_id)
    |> Repo.one()
  end

  @doc """
  Adds like where clause to any name(user_name, first_name, or last_name) in 'UserInfo' to any given `query`
  """
  def where_like_user_info(query, user_info)

  def where_like_user_info(query, user_info)
      when user_info == "" or user_info == nil,
      do: query

  def where_like_user_info(query, user_info, binded_name \\ :user_info),
    do:
      query
      |> where(
        [{^binded_name, ui}],
        like(ui.user_name, ^"%#{user_info}%") or like(ui.first_name, ^"%#{user_info}%") or
          like(ui.last_name, ^"%#{user_info}%")
      )
end
