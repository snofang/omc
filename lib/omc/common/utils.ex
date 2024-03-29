defmodule Omc.Common.Utils do
  @doc """
  Returns data_dir; create it if does not exist
  """
  def data_dir() do
    (app_dir = Application.get_env(:omc, :data))
    |> File.mkdir_p!()

    app_dir
  end

  def now(offset \\ 0, unit \\ :second) do
    NaiveDateTime.utc_now()
    |> NaiveDateTime.truncate(:second)
    |> NaiveDateTime.add(offset, unit)
  end

  def default_currency() do
    Application.get_env(:money, :default_currency)
  end

  # def validate_currency(changeset) do
  #   changeset
  #   |> Ecto.Changeset.validate_change(:currency, fn :currency, currency ->
  #     if currency in Application.get_env(:omc, :supported_currencies) do
  #       []
  #     else
  #       [currency: "unsupported currency"]
  #     end
  #   end)
  # end
end
