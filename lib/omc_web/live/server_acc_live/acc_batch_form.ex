defmodule OmcWeb.ServerAccLive.AccBatchForm do
  use OmcWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= @title %>
        <:subtitle>Use this form to create accounts.</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="acc_batch_form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="ok"
      >
        <.input
          field={@form[:server_id]}
          type="select"
          label="Server"
          prompt="Choose a server"
          options={@servers}
          disabled={@action == :edit}
        />
        <.input field={@form[:count]} type="text" label="Account's count: " />
        <:actions>
          <.button phx-disable-with="Creating accounts ...">Create</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(form: to_form(changeset(%{}), as: "acc_batch_data"))}
  end

  @data_types %{server_id: :integer, count: :integer}

  defp changeset(params) do
    {%{}, @data_types}
    |> Ecto.Changeset.cast(params, @data_types |> Map.keys())
    |> Ecto.Changeset.validate_number(:count, greater_than: 0, less_than_or_equal_to: 200)
    |> Ecto.Changeset.validate_number(:server_id, greater_than: 0)
    |> Ecto.Changeset.validate_required([:server_id, :count])
  end

  @impl true
  def handle_event("validate", %{"acc_batch_data" => data}, socket) do
    changeset =
      data
      |> changeset()
      |> Map.put(:action, :validate)

    {:noreply, socket |> assign(form: to_form(changeset, as: "acc_batch_data"))}
  end

  def handle_event("ok", %{"acc_batch_data" => data}, socket) do
    {:noreply,
     socket
     |> put_flash(
       :info,
       "#{data |> changeset() |> Map.get(:changes) |> Map.get(:count)} accounts is created"
     )}
  end

  # defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
