defmodule OmcWeb.PaymentController do
  use OmcWeb, :controller
  alias Omc.Payments
  alias OmcWeb.FallbackController

  action_fallback(FallbackController)

  def callback(conn, params) do
    with {:ok, res} <-
           Payments.callback(String.to_existing_atom(params["ipg"]), params, conn.body_params) do
      conn
      |> render(:index, res: res)
    end
  end
end
