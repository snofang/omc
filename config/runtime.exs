import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/omc start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :omc, OmcWeb.Endpoint, server: true
end

if config_env() != :test do
  config :omc, :telegram,
    token: System.get_env("OMC_TELEGRAM_TOKEN"),
    host: System.get_env("OMC_TELEGRAM_HOST")

  #
  # ipgs
  # 
  config :omc, :ipgs,
    callback_base_url: System.get_env("OMC_BASE_URL"),
    return_url: System.get_env("OMC_IPGS_RETURNURL"),
    default:
      (System.get_env("OMC_IPGS_DEFAULT") || "OXAPAY")
      |> String.downcase()
      |> String.to_existing_atom(),
    oxapay: [
      api_key: System.get_env("OMC_IPGS_OXAPAY_APIKEY") || "sandbox",
      timeout: String.to_integer(System.get_env("OMC_IPGS_OXAPAY_TIMEOUT") || "60")
    ],
    nowpayments: [
      api_key: System.get_env("OMC_IPGS_NOWPAYMENTS_APIKEY"),
      ipn_secret_key: System.get_env("OMC_IPGS_NOWPAYMENT_IPNSECRETKEY")
    ]
end

if config_env() == :prod do
  #
  # Money & Currencies
  #
  config :money,
    default_currency:
      (System.get_env("OMC_DEFAULT_CURRENCIE") || "USD")
      |> String.upcase()
      |> String.trim()
      |> String.to_atom()

  config :omc,
    supported_currencies:
      (System.get_env("OMC_SUPPORTED_CURRENCIES") || "USD,EUR")
      |> String.split(",")
      |> Enum.map(&String.upcase/1)
      |> Enum.map(&String.trim/1)
      |> Enum.map(&String.to_atom/1)

  #
  # scheduler
  #
  config :omc, Omc.Scheduler,
    jobs: [
      # default every hour
      {System.get_env("OMC_UPDATE_USAGE_CRON") || "0 * * * *", {Omc.Usages, :update_usages, []}}
    ]

  config :omc,
    data: System.get_env("OMC_DATA_PATH") || Path.expand("../../data", __DIR__),
    ansible: Path.expand("../../ansible", __DIR__)

  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :omc, Omc.Repo,
    # ssl: true,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "localhost"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :omc, OmcWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    check_origin: false,
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/plug_cowboy/Plug.Cowboy.html
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      # ip: {0, 0, 0, 0, 0, 0, 0, 0},
      ip: {0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :omc, OmcWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your endpoint, ensuring
  # no data is ever sent via http, always redirecting to https:
  #
  #     config :omc, OmcWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Also, you may need to configure the Swoosh API client of your choice if you
  # are not using SMTP. Here is an example of the configuration:
  #
  #     config :omc, Omc.Mailer,
  #       adapter: Swoosh.Adapters.Mailgun,
  #       api_key: System.get_env("MAILGUN_API_KEY"),
  #       domain: System.get_env("MAILGUN_DOMAIN")
  #
  # For this example you need include a HTTP client required by Swoosh API client.
  # Swoosh supports Hackney and Finch out of the box:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Hackney
  #
  # See https://hexdocs.pm/swoosh/Swoosh.html#module-installation for details.
end
