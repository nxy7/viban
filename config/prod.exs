import Config

# LiveVue production configuration (SSR disabled - no Node.js at runtime)
config :live_vue,
  ssr: false

config :logger, level: :info

config :viban, VibanWeb.Endpoint, cache_static_manifest: "priv/static/cache_manifest.json"
config :viban, :env, :prod
config :viban, :github_client_id, System.get_env("GH_CLIENT_ID")
