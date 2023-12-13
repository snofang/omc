defmodule Omc.UsersFixtures do
  def unique_user_id do
    (0xF000000000000000 + System.unique_integer([:positive, :monotonic]))
    |> Integer.to_string()
  end

  def unique_user_attrs do
    %{user_type: :telegram, user_id: unique_user_id()}
  end
end
