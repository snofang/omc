defmodule OmcWeb.ServerAccLive.Show do
  use OmcWeb, :live_view

  alias Omc.Servers

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:server_acc, Servers.get_server_acc!(id))}
  end

  defp page_title(:show), do: "Show Server acc"
  defp page_title(:edit), do: "Edit Server acc"
end
