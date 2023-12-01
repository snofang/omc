defmodule OmcWeb.ServerLive.Show do
  use OmcWeb, :live_view

  alias Omc.Servers
  alias Omc.PricePlans

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:server, Servers.get_server!(id))
     |> assign(
       :price_plans,
       PricePlans.list_price_plans()
       |> Enum.map(fn pp ->
         {pp.name <> (pp.prices |> List.first() |> Money.to_string()), pp.id}
       end)
     )}
  end

  defp page_title(:show), do: "Show Server"
  defp page_title(:edit), do: "Edit Server"
end
