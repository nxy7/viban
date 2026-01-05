import Config

config :viban, VibanWeb.Endpoint, cache_static_manifest: "priv/static/cache_manifest.json"

config :viban, :github_client_id, System.get_env("GH_CLIENT_ID")

config :logger, level: :info
