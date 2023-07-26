defmodule OmcWeb.ServerAccLive.Index do
  use OmcWeb, :live_view

  alias Omc.Servers
  alias Omc.Servers.ServerAcc

  @impl true
  def mount(_params, _session, socket) do
    {:ok, stream(socket, :server_accs, Servers.list_server_accs())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Server acc")
    |> assign(:server_acc, Servers.get_server_acc!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Server acc")
    |> assign(:server_acc, %ServerAcc{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Server accs")
    |> assign(:server_acc, nil)
  end

  @impl true
  def handle_info({OmcWeb.ServerAccLive.FormComponent, {:saved, server_acc}}, socket) do
    {:noreply, stream_insert(socket, :server_accs, server_acc)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    server_acc = Servers.get_server_acc!(id)
    {:ok, _} = Servers.delete_server_acc(server_acc)

    {:noreply, stream_delete(socket, :server_accs, server_acc)}
  end
end
