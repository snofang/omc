defmodule Omc.Utils do

  @doc """
  Puts given key and value into existing attr map in conformance to 
  the existing key type(s).
  This is used in such cases that both `atom` and `binary`
  key is supported and some downstream libraries such as 
  Ecto.Changeset.convert_params/1 expect uniform ones 
  (all keys of the same type).
  """
  @spec put_attr_safe!(Map, atom | binary, term) :: Map
  def put_attr_safe!(%{}=attrs, key, value) do
    case(:maps.next(:maps.iterator(attrs))) do
      {k, _, _} when is_atom(k) -> attrs |> Map.put(key, value)
      {k, _, _} when is_binary(k) -> attrs |> Map.put(to_string(key), value) 
      _ -> raise "invalid key type; only atom and binary is supported"
   end
  end
end
