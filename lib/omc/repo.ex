defmodule Omc.Repo do
  use Ecto.Repo,
    otp_app: :omc,
    adapter: Ecto.Adapters.SQLite3
end
