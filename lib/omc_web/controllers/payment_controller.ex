defmodule OmcWeb.PaymentController do
  use OmcWeb, :controller
  alias Omc.Payments
  alias OmcWeb.FallbackController

  action_fallback(FallbackController)

  def callback(conn, params) do
    with {:ok, res} <-
           Payments.callback(
             String.to_existing_atom(params["ipg"]),
             %{
               params: conn.req_headers |> Enum.into(params),
               body: OmcWeb.RawBodyReader.get_raw_body(conn)
             }
           ) do
      conn
      |> render(:index, res: res)
    end
  end
end
