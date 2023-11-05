defmodule Omc.Common.Utils do
  @doc """
  Puts given key and value into existing attr map in conformance to 
  the existing key type(s).
  This is used in such cases that both `atom` and `binary`
  key is supported and some downstream libraries such as 
  Ecto.Changeset.convert_params/1 expect uniform ones 
  (all keys of the same type).
  """
  @spec put_attr_safe!(map, atom | binary, term) :: map
  def put_attr_safe!(%{} = attrs, key, value) do
    case(:maps.next(:maps.iterator(attrs))) do
      {k, _, _} when is_atom(k) -> attrs |> Map.put(key, value)
      {k, _, _} when is_binary(k) -> attrs |> Map.put(to_string(key), value)
      :none -> attrs |> Map.put(key, value)
      _ -> raise "invalid key type; only atom and binary is supported"
    end
  end

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
end
