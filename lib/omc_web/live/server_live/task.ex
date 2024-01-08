defmodule OmcWeb.ServerLive.Task do
  alias Omc.ServerTasks
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
      max_length =
        Application.get_env(:omc, Omc.Servers.ServerTaskManager)[:max_log_length_per_server] ||
          1_000

      {:noreply,
       socket
       |> assign(
         :task_log,
         ((Map.get(socket.assigns, :task_log) || "") <> prompt)
         |> String.slice(-max_length, max_length)
       )}
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

  def handle_event("sync-accs", _unsigned_params, socket) do
    ServerTasks.sync_accs_server_task(socket.assigns.server, true)
    {:noreply, socket}
  end

  def handle_event("clear-log", _unsigned_params, socket) do
    ServerTaskManager.clear_task_log(socket.assigns.server.id)
    {:noreply, socket |> assign(task_log: "")}
  end

  def handle_event("cancel-running-task", _unsigned_params, socket) do
    ServerTaskManager.cancel_running_task(socket.assigns.server.id)
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
          <.button
            phx-click="ovpn-config-push"
            data-confirm="Are you sure? all config data in the server will be overwritten"
          >
            ovpn push
          </.button>
          <.button phx-click="sync-accs">Sync Accounts</.button>
          <.button phx-click="cancel-running-task">Cancel Running Task</.button>
          <.button phx-click="clear-log">Clear Log</.button>
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
