defmodule OmcWeb.ConsoleRedirector do
  use OmcWeb, :verified_routes
  import Plug.Conn
  import Phoenix.Controller, only: [redirect: 2, put_flash: 3]

  def init(opts) do
    opts
  end

  def call(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
      |> redirect(to: ~p"/users/console")
      |> halt()
    else
      conn
      |> put_flash(:error, "You must log in to access this page.")
      |> maybe_store_return_to()
      |> redirect(to: ~p"/users/log_in")
      |> halt()
    end
  end

  defp maybe_store_return_to(%{method: "GET"} = conn) do
    put_session(conn, :user_return_to, ~p"/users/console")
  end
end
