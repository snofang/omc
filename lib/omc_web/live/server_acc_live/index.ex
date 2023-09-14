defmodule OmcWeb.ServerAccLive.Index do
  use OmcWeb, :live_view

  alias Omc.Servers
  alias Omc.Servers.ServerAcc

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:servers, Servers.list_servers() |> Enum.map(&{&1.name, &1.id}))
      |> assign(:bindings, [])
      |> assign(:filter_form, to_form(params_to_changeset(%{})))
      |> assign(:page, 1)
      |> stream(:server_accs, [], reset: true)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply,
     socket
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Server Account")
    |> assign(:server_acc, Servers.get_server_acc!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Server Account")
    |> assign(:server_acc, %ServerAcc{})
  end

  defp apply_action(socket, :new_batch, _params) do
    socket
    |> assign(:page_title, "New Server accs")
  end

  defp apply_action(socket, :index, params) do
    bindings = params_to_bindings(params)

    socket
    |> assign(:filter_form, to_form(params_to_changeset(params)))
    |> assign(:bindings, bindings)
    |> assign(:page_title, "Listing Server Accounts")
    |> stream(:server_accs, Servers.list_server_accs(bindings), reset: true)
    |> assign(:page, 1)
  end

  @impl true
  def handle_info({OmcWeb.ServerAccLive.FormComponent, {:saved, server_acc}}, socket) do
    {:noreply, stream_insert(socket, :server_accs, server_acc)}
  end

  def handle_event("load_more", _params, %{assigns: %{page: page, bindings: bindings}} = socket) do
    {:noreply,
     Servers.list_server_accs(bindings, page + 1)
     |> Enum.reduce(socket, fn a, s -> stream_insert(s, :server_accs, a, at: -1) end)
     |> assign(:page, page + 1)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    server_acc = Servers.get_server_acc!(id)
    {:ok, _} = Servers.delete_server_acc(server_acc)

    {:noreply, stream_delete(socket, :server_accs, server_acc)}
  end

  @impl true
  def handle_event("deactivate", %{"id" => id}, socket) do
    server_acc = Servers.get_server_acc!(id)
    {:ok, update_server_acc} = Servers.deactivate_acc(server_acc)

    {:noreply, stream_insert(socket, :server_accs, update_server_acc, at: -1)}
  end
  
  def handle_event("change-filter", %{"filter" => params}, socket) do
    {:noreply, socket |> push_patch(to: ~p"/server_accs?#{params_to_bindings(params)}")}
  end

  defp params_to_changeset(params) do
    # manually drop empty value change for status to prevent auto falling back to default status
    params = params |> Map.reject(fn {key, value} -> key == "status" and value == "" end)

    %ServerAcc{server_id: nil, name: nil, status: ""}
    |> Ecto.Changeset.cast(params, [:server_id, :name, :status])
  end

  defp params_to_bindings(params) do
    params
    |> params_to_changeset()
    |> Map.get(:changes)
  end
end
