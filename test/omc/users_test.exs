defmodule Omc.UsersTest do
  use Omc.DataCase, async: true
  alias Omc.Users
  alias Omc.UsersFixtures

  describe "upsert_user_info/1" do
    setup %{} do
      user_attrs =
        UsersFixtures.unique_user_attrs()
        |> Map.merge(%{
          user_name: "Jashoo",
          first_name: "James",
          last_name: "Shames",
          language_code: "en"
        })

      %{user_attrs: user_attrs}
    end

    test "success case; new user", %{user_attrs: user_attrs} do
      assert nil == Users.get_user_info(user_attrs)
      {:ok, user_info} = Users.upsert_user_info(user_attrs)
      assert user_info == Users.get_user_info(user_attrs)
    end

    test "success case; update user", %{user_attrs: user_attrs} do
      {:ok, _} = Users.upsert_user_info(user_attrs)

      new_user_attrs =
        user_attrs
        |> Map.merge(%{
          user_name: "Jashoo1",
          first_name: "James1",
          last_name: "Shames1",
          language_code: "fr"
        })

      assert {:ok,
              %{
                user_name: "Jashoo1",
                first_name: "James1",
                last_name: "Shames1",
                language_code: "fr"
              }} = Users.upsert_user_info(new_user_attrs)
    end
  end
end
