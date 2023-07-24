defmodule OmcWeb.Nav do
  import Phoenix.LiveView
  use Phoenix.Component

  alias OmcWeb.Console
  alias OmcWeb.{Console, UserSettingsLive}

  def on_mount(:default, _params, _session, socket) do
    {:cont,
     socket
     |> assign(:region, System.get_env("FLY_REGION") || "iad")
     |> attach_hook(:active_tab, :handle_params, &handle_active_tab_params/3)}
  end

  defp handle_active_tab_params(_params, _url, socket) do
    active_tab =
      case {socket.view, socket.assigns.live_action} do
        {Console, _} ->
          :console

        {UserSettingsLive, _} ->
          :settings

        {_, _} ->
          nil
      end

    {:cont, assign(socket, active_tab: active_tab)}
  end
end
