defmodule Omc.ServersFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Omc.Servers` context.
  """
  alias Omc.Servers
  alias Omc.Servers.{ServerOps}

  @doc """
  Generate a unique server name.
  """
  def unique_server_name, do: "somename#{System.unique_integer([:positive])}"
  def unique_server_acc_name, do: "somename#{System.unique_integer([:positive])}"

  def server_valid_attrs() do
    %{
      tag: "some-tag",
      name: unique_server_name(),
      price: "120.50"
    }
  end

  @doc """
  Generate a server.
  """
  def server_fixture(attrs \\ %{}) do
    {:ok, server} =
      attrs
      |> Enum.into(server_valid_attrs())
      |> Omc.Servers.create_server()

    server
  end

  @doc """
  Generate a server_acc.
  """
  def server_acc_fixture(attrs \\ %{}) do
    {:ok, server_acc} =
      attrs
      |> Enum.into(%{
        description: "some description",
        name: unique_server_acc_name()
      })
      |> Omc.Servers.create_server_acc()

    server_acc
  end

  def activate_server_acc(server, server_acc) do
    # :active_pending &  File.exists -> :active
    acc_file_path(server_acc) |> File.touch()
    Servers.sync_server_accs_status(server.id)
  end

  def acc_file_path(server_acc) do
    file_path = ServerOps.acc_file_path(server_acc)
    # this path should be created during pull from server
    Path.dirname(file_path) |> File.mkdir_p()
    file_path
  end
end
