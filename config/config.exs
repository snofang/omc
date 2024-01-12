# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :omc,
  data: Path.expand("../.data", Path.dirname(__ENV__.file)),
  ansible: Path.expand("../rel/overlays/ansible", Path.dirname(__ENV__.file))

#
# money & currency
# 
config :money,
  default_currency: :USD

config :omc, supported_currencies: [:USD]
config :omc, acc_allocation_timeout: 30 * 60

#
# ipgs
# 
config :omc, :ipgs,
  callback_base_url: "http://localhost:4000",
  return_url: "https://t.me/your_fantastic_bot",
  default: :oxapay,
  oxapay: [
    currencies: [:USD],
    module: Omc.Payments.PaymentProviderOxapay,
    base_url: "https://api.oxapay.com/merchants",
    api_key: "sandbox",
    timeout: (Application.get_env(:omc, :acc_allocation_timeout, 30 * 60) / 60) |> round()
  ],
  nowpayments: [
    currencies: [:USD],
    module: Omc.Payments.PaymentProviderNowpayments,
    base_url: "https://api-sandbox.nowpayments.io/v1",
    api_key: "runtime resolved",
    ipn_secret_key: "runtime resolved"
  ]

#
# scheduler
#
config :omc, Omc.Scheduler,
  jobs: [
    # runs every minutes and allocation timeout is 15 minutes
    # {"* * * * *", {Omc.ServerAccUsers, :cleanup_acc_allocations, [15 * 60]}}, 
  ]

#
# Telegram
#
config :omc, :telegram,
  enabled: true,
  token: "this should be provided via system environment variable",
  max_bot_concurrency: 1_000,
  api_impl: Omc.Telegram.TelegramApiImpl,
  host: "telegram.example.com"

config :omc, Omc.Payments, enabled: true

config :omc, Omc.Servers.ServerTaskManager,
  enabled: true,
  max_log_length_per_server: 4000

config :omc, Omc.ServerTasks,
  enabled: true,
  batch_size: 5,
  batch_size_max: 200

config :omc, Omc.Usages, acc_min_usage_days: 5

config :telegram,
  webserver: Telegram.WebServer.Cowboy

config :tesla, adapter: {Tesla.Adapter.Hackney, [recv_timeout: 40_000]}

config :omc,
  ecto_repos: [Omc.Repo]

config :omc, cmd_wrapper_impl: Omc.Common.CmdWrapperImpl
config :omc, server_call_timeout: 15 * 60 * 1_000

# Configures the endpoint
config :omc, OmcWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [
    formats: [html: OmcWeb.ErrorHTML, json: OmcWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Omc.PubSub,
  live_view: [signing_salt: "q5tmBs0T"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :omc, Omc.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.2.7",
  default: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
