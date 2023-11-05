import Config

# For production, don't forget to configure the url host
# to something meaningful, Phoenix uses this information
# when generating URLs.

# Note we also include the path to a cache manifest
# containing the digested version of static files. This
# manifest is generated by the `mix assets.deploy` task,
# which you should run after static files are built and
# before starting your production server.
config :omc, OmcWeb.Endpoint, cache_static_manifest: "priv/static/cache_manifest.json"

# Configures Swoosh API Client
config :swoosh, api_client: Swoosh.ApiClient.Finch, finch_name: Omc.Finch

# Do not print debug messages in production
config :logger, level: :info

# Runtime production configuration, including reading
# of environment variables, is done on config/runtime.exs.

#
# scheduler
#
config :omc, Omc.Scheduler,
  jobs: [
    # runs every minutes and allocation timeout 
    {"* * * * *",
     {Omc.ServerAccUsers, :cleanup_acc_allocations,
      [Application.get_env(:omc, :acc_allocation_timeout)]}},
    
    # updating usages every hour
    {"* 0 * * *", {Omc.Usages, :update_usages, []}}
    
    # runs every minutes and updates ledgers by payments, better to have passed the duration param
    # a little bit more that peroic calls and have overlap to not miss anything
    # the duration is in seconds
    {"* * * * *", {Omc.Payments, :update_ledgers, [65]}}
  ]
