defmodule Omc.ServersFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Omc.Servers` context.
  """
  alias Omc.PricePlans
  alias Omc.Servers
  alias Omc.Servers.{ServerOps}

  @doc """
  Generate a unique server name.
  """
  def unique_server_name, do: "somename#{System.unique_integer([:positive])}.com"
  defp ip_token, do: System.unique_integer([:positive, :monotonic]) |> rem(256)

  # How much calls should happen for this to generate a repetitive IP? it should be very big! :TODO
  def unique_server_address, do: "#{ip_token()}.#{ip_token()}.#{ip_token()}.#{ip_token()}"
  def unique_server_acc_name, do: "somename#{System.unique_integer([:positive])}"

  def server_valid_attrs() do
    {:ok, price_plan} = PricePlans.create_price_plan(Money.new(12050))

    %{
      tag: "from-to",
      address: unique_server_address(),
      name: unique_server_name(),
      price_plan_id: price_plan.id,
      price_plan: price_plan,
      max_acc_count: 150
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

    # refetching server to get price plan filled
    Servers.get_server!(server.id)
  end

  @doc """
  Generate a server_acc.
  At least server id should be specified.
  ## Examples:
    server_acc_fixture(%{server_id: server_id})
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
