defmodule OmcWeb.ServerLive.Task do
  alias Omc.Servers
  alias Omc.Servers.ServerTaskManager
  alias Omc.Servers.ServerOps
  use OmcWeb, :live_view
  require Logger

  def mount(params, _session, socket) do
    Logger.info("mount parameters: #{inspect(params)}")
    {:ok, socket}
  end

  def handle_params(%{"id" => id}, _uri, socket) do
    server = Servers.get_server!(id)
    if connected?(socket), do: Process.send_after(self(), :update, 1_000)

    {:noreply,
     socket
     # Servers.get_server!(id))
     |> assign(server: server)
     |> assign(:page_title, "Server Task - #{server.id} - #{server.name}")
     |> assign(task_log: server |> ServerTaskManager.get_task_log())}
  end

  def handle_info(:update, socket) do
    Process.send_after(self(), :update, 1_000)

    {:noreply,
     assign(socket, :task_log, ServerTaskManager.get_task_log(socket.assigns.server.id))}
  end

  def handle_event("ovpn", _unsigned_params, socket) do
    Logger.info("ovpn-install task called for #{inspect(socket.assigns.server)}")
    ServerOps.ansible_ovpn_install(socket.assigns.server)
    {:noreply, socket}
  end

  def handle_event("ovpn-config-push", _unsigned_params, socket) do
    Logger.info("ovpn-install task called for #{inspect(socket.assigns.server)}")
    ServerOps.ansible_ovpn_install(socket.assigns.server, true)
    {:noreply, socket}
  end
  
  def render(assigns) do
    ~H"""
    <div class="mx-5">
      <.header>
        <%= @page_title %>
        <:subtitle>Server tasks - <%= @server.name %></:subtitle>
        <:actions>
          <.button phx-click="ovpn">ovpn</.button>
          <.button phx-click="ovpn-config-push" data-confirm="Are you sure? all config data in the server will be overwritten">ovpn as source</.button>
        </:actions>
        <div></div>
      </.header>
      <div id="task-{@server.id}" class="whitespace-pre-line font-mono text-xs border-2 p-2"><%= @task_log %></div>
      <.back navigate={~p"/servers"}>Back to servers</.back>
    </div>
    """
  end
end
