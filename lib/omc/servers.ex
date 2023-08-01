defmodule Omc.Servers do
  @moduledoc """
  The Servers context.
  """

  import Ecto.Query, warn: false
  alias Omc.Repo

  alias Omc.Servers.Server

  @doc """
  Returns the list of servers.

  ## Examples

      iex> list_servers()
      [%Server{}, ...]

  """
  def list_servers do
    Repo.all(Server)
  end

  @doc """
  Gets a single server.

  Raises `Ecto.NoResultsError` if the Server does not exist.

  ## Examples

      iex> get_server!(123)
      %Server{}

      iex> get_server!(456)
      ** (Ecto.NoResultsError)

  """
  def get_server!(id), do: Repo.get!(Server, id)

  @doc """
  Creates a server.

  ## Examples

      iex> create_server(%{field: value})
      {:ok, %Server{}}

      iex> create_server(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_server(attrs \\ %{}) do
    %Server{}
    |> Server.changeset(
      attrs
      |> Omc.Utils.put_attr_safe!(:status, :active)
    )
    |> Repo.insert()
  end

  @doc """
  Updates a server.

  ## Examples

      iex> update_server(server, %{field: new_value})
      {:ok, %Server{}}

      iex> update_server(server, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_server(%Server{} = server, attrs) do
    server
    |> Server.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a server.

  ## Examples

      iex> delete_server(server)
      {:ok, %Server{}}

      iex> delete_server(server)
      {:error, %Ecto.Changeset{}}

  """
  def delete_server(%Server{} = server) do
    Repo.delete(server)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking server changes.

  ## Examples

      iex> change_server(server)
      %Ecto.Changeset{data: %Server{}}

  """
  def change_server(%Server{} = server, attrs \\ %{}) do
    Server.changeset(server, attrs)
  end

  alias Omc.Servers.ServerAcc

  @doc """
  Returns the list of server_accs.

  ## Examples

      iex> list_server_accs()
      [%ServerAcc{}, ...]

  """
  def list_server_accs do
    Repo.all(ServerAcc)
  end

  def list_server_accs(server_id) when server_id == "" or server_id == nil do
    from(sc in ServerAcc, where: is_nil(sc.server_id))
    |> Repo.all()
  end

  def list_server_accs(server_id) do
    ServerAcc
    |> where(server_id: ^server_id)
    |> Repo.all()
  end

  @doc """
  Gets a single server_acc.

  Raises `Ecto.NoResultsError` if the Server acc does not exist.

  ## Examples

      iex> get_server_acc!(123)
      %ServerAcc{}

      iex> get_server_acc!(456)
      ** (Ecto.NoResultsError)

  """
  def get_server_acc!(id), do: Repo.get!(ServerAcc, id)

  @doc """
  Creates a server_acc.

  ## Examples

      iex> create_server_acc(%{field: value})
      {:ok, %ServerAcc{}}

      iex> create_server_acc(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_server_acc(attrs \\ %{}) do
    %ServerAcc{}
    |> ServerAcc.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a server_acc.

  ## Examples

      iex> update_server_acc(server_acc, %{field: new_value})
      {:ok, %ServerAcc{}}

      iex> update_server_acc(server_acc, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_server_acc(%ServerAcc{} = server_acc, attrs) do
    server_acc
    |> ServerAcc.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a server_acc.

  ## Examples

      iex> delete_server_acc(server_acc)
      {:ok, %ServerAcc{}}

      iex> delete_server_acc(server_acc)
      {:error, %Ecto.Changeset{}}

  """
  def delete_server_acc(%ServerAcc{} = server_acc) do
    Repo.delete(server_acc)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking server_acc changes.

  ## Examples

      iex> change_server_acc(server_acc)
      %Ecto.Changeset{data: %ServerAcc{}}

  """
  def change_server_acc(%ServerAcc{} = server_acc, attrs \\ %{}) do
    ServerAcc.changeset(server_acc, attrs)
  end
end
