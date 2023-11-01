defmodule OmcWeb.FallbackController do
  use OmcWeb, :controller

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(json: OmcWeb.ErrorJSON)
    |> render(:"404", processed_response: :not_found)
  end

  def call(conn, {:error, processed_response}) do
    conn
    |> put_status(:bad_request)
    |> put_view(json: OmcWeb.ErrorJSON)
    |> render(nil, processed_response: processed_response)
  end
end
