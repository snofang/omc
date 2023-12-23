defmodule OmcWeb.PaymentRequestLive.Index do
  alias Omc.Payments.PaymentRequest
  use OmcWeb, :live_view
  alias Omc.Payments

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, params) do
    socket
    |> assign(:filter_form, to_form(params_to_changeset(params), as: :filter))
    |> assign(:bindings, params_to_bindings(params))
    |> assign(:page_title, "Listing Payment requests")
    |> stream(:payment_requests, Payments.list_payment_requests(params_to_keyword(params, 1)),
      reset: true
    )
    |> assign(page: 1)
  end

  @impl true
  def handle_event("load_more", _params, %{assigns: %{page: page, bindings: bindings}} = socket) do
    {:noreply,
     socket
     |> stream(
       :payment_requests,
       Payments.list_payment_requests(params_to_keyword(bindings, page + 1))
     )
     |> assign(:page, page + 1)}
  end

  @impl true
  def handle_event("change-filter", %{"filter" => params}, socket) do
    {:noreply, socket |> push_patch(to: ~p"/payment_requests?#{params_to_bindings(params)}")}
  end

  def handle_event("inquiry_state", %{"id" => id}, socket) do
    {:noreply,
     Payments.get_payment_request!(id)
     |> Payments.send_state_inquiry_request()
     |> case do
       {:ok, _} ->
         socket |> put_flash(:info, "Got inquiry resoponse successfully.")

       {:error, error} ->
         socket |> put_flash(:error, "Error status inquiry; cause: #{inspect(error)}")
     end}
  end

  defp params_to_changeset(params) do
    {%{
       user_type: nil,
       user_id: nil,
       paid?: nil
     },
     %{
       user_type: PaymentRequest.__schema__(:type, :user_type),
       user_id: PaymentRequest.__schema__(:type, :user_id),
       paid?: :boolean
     }}
    |> Ecto.Changeset.cast(params, [:user_type, :user_id, :paid?])
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
