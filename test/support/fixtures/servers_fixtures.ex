defmodule Omc.ServersFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Omc.Servers` context.
  """

  @doc """
  Generate a unique server name.
  """
  def unique_server_name, do: "somename#{System.unique_integer([:positive])}"

  @doc """
  Generate a server.
  """
  def server_fixture(attrs \\ %{}) do
    {:ok, server} =
      attrs
      |> Enum.into(%{
        description: "some description",
        max_accs: 42,
        name: unique_server_name(),
        price: "120.5"
        # status: :active
      })
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
        name: "some name",
        status: :active
      })
      |> Omc.Servers.create_server_acc()

    server_acc
  end
end
