defmodule OmcWeb.LedgerLive.Index do
  alias Omc.Ledgers.Ledger
  use OmcWeb, :live_view
  alias Omc.Ledgers

  @impl true
  def mount(params, _session, socket) do
    {:ok,
     socket
     |> assign(:show_new_tx_modal, false)
     |> assign(:filter_form, to_form(params_to_changeset(params)))
     |> assign(:bindings, params_to_bindings(params))
     |> stream(:ledgers, Ledgers.list_ledgers(params_to_keyword(params, 1)), reset: true)
     |> assign(page: 1)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, params) do
    socket
    |> assign(:show_new_tx_modal, false)
    |> assign(:filter_form, to_form(params_to_changeset(params)))
    |> assign(:page_title, "Listing Ledgers")
    |> assign_list_ledgers_and_bindings(params)
  end

  defp assign_list_ledgers_and_bindings(socket, params) do
    if(socket.assigns.bindings != params_to_bindings(params)) do
      socket
      |> stream(:ledgers, Ledgers.list_ledgers(params_to_keyword(params, 1)), reset: true)
      |> assign(:bindings, params_to_bindings(params))
    else
      socket
    end
  end

  @impl true
  def handle_event("load_more", _params, %{assigns: %{page: page, bindings: bindings}} = socket) do
    {:noreply,
     socket
     |> stream(
       :ledgers,
       Ledgers.list_ledgers(params_to_keyword(bindings, page + 1))
     )
     |> assign(:page, page + 1)}
  end

  def handle_event("new_tx", %{"id" => id}, socket) do
    {:noreply,
     socket
     |> assign(:show_new_tx_modal, true)
     |> assign(:page_title, "New Ledger Tx")
     |> assign(:ledger, Ledgers.get_ledger!(id))
     |> assign(:patch, ~p"/ledgers?#{socket.assigns.bindings}")}
  end

  @impl true
  def handle_event("change-filter", %{"filter" => params}, socket) do
    {:noreply, socket |> push_patch(to: ~p"/ledgers?#{params_to_bindings(params)}")}
  end

  @impl true
  def handle_info({OmcWeb.LedgerLive.FormComponent, {:new_tx_created, ledger}}, socket) do
    {:noreply, stream_insert(socket, :ledgers, ledger)}
  end

  defp params_to_changeset(params) do
    %Ledger{}
    |> Ecto.Changeset.cast(params, [:user_type, :user_id, :currency])
  end

  defp params_to_bindings(params) do
    params
    |> params_to_changeset()
    |> Map.get(:changes)
  end

  defp params_to_keyword(params, page) do
    Keyword.new(params_to_bindings(params)) |> Keyword.put(:page, page)
  end
end
