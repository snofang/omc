defmodule OmcWeb.ServerLive.Task do
  alias Phoenix.PubSub
  alias Omc.Servers
  alias Omc.Servers.ServerTaskManager
  alias Omc.Servers.ServerOps
  use OmcWeb, :live_view
  require Logger

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def handle_params(%{"id" => id}, _uri, socket) do
    server = Servers.get_server!(id)
    if connected?(socket), do: PubSub.subscribe(Omc.PubSub, "server_task_progress")

    {:noreply,
     socket
     # Servers.get_server!(id))
     |> assign(server: server)
     |> assign(:page_title, "Server Task - #{server.id} - #{server.name}")
     |> assign(task_log: server.id |> ServerTaskManager.get_task_log())}
  end

  def handle_info({:progress, server_id, prompt}, socket) do
    if socket.assigns.server.id == server_id do
      {:noreply,
       socket
       |> assign(:task_log, (Map.get(socket.assigns, :task_log) || "") <> prompt)}
    else
      {:noreply, socket}
    end
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

  def handle_event("ovpn-acc-update", _unsigned_params, socket) do
    Logger.info("ovpn-acc-update task called for #{inspect(socket.assigns.server)}")
    ServerOps.ansible_ovpn_accs_update(socket.assigns.server)
    {:noreply, socket}
  end

  def handle_event("sync-acc-data", _unsigned_params, socket) do
    Servers.sync_server_accs_status(socket.assigns.server)
    {:noreply, socket}
  end

  def handle_event("clear-log", _unsigned_params, socket) do
    ServerTaskManager.clear_task_log(socket.assigns.server.id)
    {:noreply, socket |> assign(task_log: "")}
  end

  def render(assigns) do
    ~H"""
    <div class="mx-5">
      <.header>
        <%= @page_title %>
        <:subtitle>Server tasks - <%= @server.name %></:subtitle>
        <:actions>
          <.button phx-click="ovpn">ovpn</.button>
          <.button
            phx-click="ovpn-config-push"
            data-confirm="Are you sure? all config data in the server will be overwritten"
          >
            ovpn push
          </.button>
          <.button phx-click="ovpn-acc-update">ovpn acc update</.button>
          <.button phx-click="sync-acc-data">sync acc data</.button>
          <.button phx-click="clear-log">clear log</.button>
        </:actions>
        <div></div>
      </.header>
      <div id="task-{@server.id}" class="whitespace-pre-line font-mono text-xs border-2 p-2">
        <%= @task_log %>
      </div>
      <.back navigate={~p"/servers"}>Back to servers</.back>
    </div>
    """
  end
end
