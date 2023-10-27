defmodule OmcWeb.FallbackController do
  use OmcWeb, :controller

  def call(conn, {:error, processed_response = %{error: "NOT_FOUND"}}) do
    conn
    |> put_status(:not_found)
    |> put_view(json: OmcWeb.ErrorJSON)
    |> render(:"404", processed_response: processed_response)
  end

  def call(conn, {:error, %{} = processed_response}) do
    conn
    |> put_status(:bad_request)
    |> put_view(json: OmcWeb.ErrorJSON)
    |> render(:"400", processed_response: processed_response)
  end
end
