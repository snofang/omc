defmodule OmcWeb.ServerLive.Index do
  require Logger
  alias Omc.PricePlans
  use OmcWeb, :live_view

  alias Omc.Servers
  alias Omc.Servers.Server

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> stream(:servers, Servers.list_servers())
     |> assign(
       :price_plans,
       PricePlans.list_price_plans()
       |> Enum.map(fn pp ->
         {pp.name <> (pp.prices |> List.first() |> Money.to_string()), pp.id}
       end)
     )}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Server")
    |> assign(:server, Servers.get_server!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Server")
    |> assign(:server, %Server{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Servers")
    |> assign(:server, nil)
  end

  @impl true
  def handle_info({OmcWeb.ServerLive.FormComponent, {:saved, server}}, socket) do
    {:noreply, stream_insert(socket, :servers, server)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    server = Servers.get_server!(id)

    case Servers.delete_server(server) do
      {:ok, _} ->
        {:noreply, stream_delete(socket, :servers, server)}

      {:error, %{errors: [{_, {msg, _}} | _]}} ->
        {:noreply,
         socket
         |> put_flash(:error, msg)}
    end
  end
end
