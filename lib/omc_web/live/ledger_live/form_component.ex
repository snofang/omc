defmodule OmcWeb.LedgerLive.FormComponent do
  alias Omc.Ledgers.LedgerTxAux
  use OmcWeb, :live_component
  Phoenix.LiveComponent

  alias Omc.Ledgers

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= @title %>
        <:subtitle>Creating manual ledger transaction.</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="ledger-tx-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input
          field={@form[:user_type]}
          type="select"
          label="User Type"
          prompt="Choose a value"
          options={Ecto.Enum.values(Omc.Ledgers.LedgerTxAux, :user_type)}
          disabled={@id != :new}
        />
        <.input field={@form[:user_id]} type="text" label="User Id" disabled={@id != :new} />
        <.input
          field={@form[:currency]}
          type="select"
          label="Currency"
          prompt="Choose a value"
          options={Ecto.Enum.values(Omc.Ledgers.LedgerTxAux, :currency)}
          disabled={@id != :new}
        />
        <.input
          field={@form[:type]}
          type="select"
          label="Tx Type"
          prompt="Choose a value"
          options={Ecto.Enum.values(Omc.Ledgers.LedgerTxAux, :type)}
        />

        <.input field={@form[:amount]} type="text" label="Amount" />
        <:actions>
          <.button phx-disable-with="Creating Tx...">Create Tx</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{ledger: ledger} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_form(changeset(ledger, %{}))}
  end

  @impl true
  def handle_event("validate", %{"ledger_tx_aux" => params}, socket) do
    changeset =
      changeset(socket.assigns.ledger, params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"ledger_tx_aux" => params}, socket) do
    changeset = changeset(socket.assigns.ledger, params)

    if changeset.valid? do
      try do
        data = Ecto.Changeset.apply_changes(changeset)

        %{ledger: ledger, ledger_tx: _} =
          Ledgers.create_ledger_tx!(%{
            user_type: data.user_type,
            user_id: data.user_id,
            context: :manual,
            money:
              Money.parse(data.amount, data.currency)
              |> then(fn {:ok, amount} -> amount end),
            type: data.type
          })

        notify_parent({:new_tx_created, ledger})

        {:noreply,
         socket
         |> put_flash(:info, "Ledger Tx created succesfully.")
         |> push_patch(to: socket.assigns.patch)}
      rescue
        error ->
          {
            :noreply,
            socket
            |> put_flash(:error, "Ledger Tx creation failed; #{inspect(error)}")
            |> push_patch(to: socket.assigns.patch)
          }

          # |> assign_form(changeset(socket.assigns.ledger, params))}
      end
    else
      {:noreply,
       socket
       |> assign_form(changeset |> Map.put(:action, :validate))}
    end
  end

  defp changeset(ledger, params) do
    %LedgerTxAux{
      user_type: ledger.user_type,
      user_id: ledger.user_id,
      currency: ledger.currency
    }
    |> LedgerTxAux.changeset(params)
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
