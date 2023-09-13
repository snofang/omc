defmodule OmcWeb.ServerAccLive.FormComponent do
  use OmcWeb, :live_component

  alias Omc.Servers

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= @title %>
        <:subtitle>Use this form to manage server_acc records in your database.</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="server_acc-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input
          field={@form[:server_id]}
          type="select"
          label="Server"
          prompt="Choose a server"
          options={@servers}
          disabled={@action == :edit}
        />
        <.input
          field={@form[:name]}
          type="text"
          label="Name"
          disabled={@action == :edit and @server_acc.status != :active_pending}
        />
        <.input
          field={@form[:status]}
          type="select"
          label="Status"
          prompt="Choose a value"
          options={Ecto.Enum.values(Omc.Servers.ServerAcc, :status)}
          disabled
        />
        <.input field={@form[:description]} type="text" label="Description" />
        <:actions>
          <.button phx-disable-with="Saving...">Save Server acc</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{server_acc: server_acc} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_form(Servers.change_server_acc(server_acc))}
  end

  @impl true
  def handle_event("validate", %{"server_acc" => server_acc_params}, socket) do
    changeset =
      socket.assigns.server_acc
      |> Servers.change_server_acc(server_acc_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"server_acc" => server_acc_params}, socket) do
    save_server_acc(socket, socket.assigns.action, server_acc_params)
  end

  defp save_server_acc(socket, :edit, server_acc_params) do
    case Servers.update_server_acc(socket.assigns.server_acc, server_acc_params) do
      {:ok, server_acc} ->
        notify_parent({:saved, server_acc})

        {:noreply,
         socket
         |> put_flash(:info, "Server acc updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_server_acc(socket, :new, server_acc_params) do
    case Servers.create_server_acc(server_acc_params) do
      {:ok, _server_acc} ->
        # notify_parent({:saved, server_acc})

        {:noreply,
         socket
         |> put_flash(:info, "Server acc created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
