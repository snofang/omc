defmodule Omc.Users.UserInfo do
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_info" do
    field :first_name, :string
    field :language_code, :string
    field :last_name, :string
    field :user_id, :string
    field :user_name, :string
    field :user_type, Ecto.Enum, values: [:telegram, :local]

    timestamps()
  end

  @doc false
  def changeset(user_info, attrs) do
    user_info
    |> cast(attrs, [:user_type, :user_id, :user_name, :first_name, :last_name, :language_code])
    |> validate_required([:user_type, :user_id])
  end
end
