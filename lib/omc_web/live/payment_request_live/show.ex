defmodule OmcWeb.PaymentRequestLive.Show do
  use OmcWeb, :live_view

  alias Omc.Payments

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(params = %{"id" => id}, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:payment_request, Payments.get_payment_request!(id))
     |> assign(:navigate_back, Map.get(params, "navigate_back"))}
  end

  defp page_title(:show), do: "Show Payment request"
end
