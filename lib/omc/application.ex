defmodule Omc.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        # Start the Telemetry supervisor
        OmcWeb.Telemetry,
        # Start the Ecto repository
        Omc.Repo,
        # Start the PubSub system
        {Phoenix.PubSub, name: Omc.PubSub},
        # Start Finch
        {Finch, name: Omc.Finch},
        # Start the Endpoint (http/https)
        OmcWeb.Endpoint,
        # Start the TaskSupervisor
        {Task.Supervisor, name: Omc.TaskSupervisor},
        # Start ServerTaskManager
        Omc.Servers.ServerTaskManager,
        # Scheduler
        Omc.Scheduler,
        Omc.Payments
      ]
      # Start Telegram bot 
      |> add_if(
        Application.get_env(:omc, :telegram)[:enabled],
        {Telegram.Webhook,
         config: telegram_webhook_config(), bots: [{Omc.TelegramBot, telegram_bot_args()}]}
      )

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Omc.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    OmcWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp telegram_bot_args() do
    [
      token: Application.get_env(:omc, :telegram)[:token],
      max_bot_concurrency: Application.get_env(:omc, :telegram)[:max_bot_concurrency]
    ]
  end

  defp telegram_webhook_config() do
    [
      host: Application.get_env(:omc, :telegram)[:host],
      port: 443,
      local_port: 4_001
    ]
  end

  def add_if(list, condition, item), do: if(condition, do: list ++ [item], else: list)
end
