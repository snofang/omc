import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

#
# money & currency
# 
config :omc, supported_currencies: [:IRR, :USD, :EUR]

#
# ipgs
# 
config :omc, :ipgs,
  # Note: the whole purpose of providing this config here is to let `base_url` have non `sandbox` value
  nowpayments: [
    module: Omc.Payments.PaymentProviderNowpayments,
    base_url: "https://api.nowpayments.io/v1",
    api_key: "runtime resolved",
    ipn_secret_key: "runtime resolved"
  ]

config :omc, :telegram, enabled: false
config :omc, Omc.Payments, enabled: false
config :omc, Omc.Servers.ServerTaskManager, enabled: false

# config :tesla, Omc.Payments.PaymentProviderOxapay, adapter: Omc.TeslaMock
config :tesla, adapter: Omc.TeslaMock

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :omc, Omc.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "omc_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :omc, OmcWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "T7TPljDIWiqCsMtMe7sCz43aNiLIoCoSZmWhmnVGw1wVNdN1KnrKQUY3YWfcuV/X",
  server: false

# In test we don't send emails.
config :omc, Omc.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :error

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
