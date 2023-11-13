defmodule OmcWeb.LedgerLive.Show do
  use OmcWeb, :live_view

  alias Omc.Ledgers

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(params = %{"id" => id}, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:ledger, Ledgers.get_ledger!(id))
     |> assign(:ledger_txs, Ledgers.get_ledger_txs_by_ledger_id(id))
     |> assign(:navigate_back, Map.get(params, "navigate_back"))}
  end

  defp page_title(:show), do: "Show Ledger Detail"
end
