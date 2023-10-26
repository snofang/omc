defmodule OmcWeb.FallbackController do
  use OmcWeb, :controller

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(json: OmcWeb.ErrorJSON)
    |> render(:"404")
  end
end
