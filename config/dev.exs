import Config

# LiveVue configuration (SSR disabled for single-binary deployment)
config :live_vue,
  vite_host: "http://localhost:5173",
  ssr: false

config :logger, :console, format: "$metadata[$level] $message\n"
config :logger, level: :info

config :phoenix, :plug_init_mode, :runtime
config :phoenix, :stacktrace_depth, 20

# Phoenix runs on HTTP on port 7777
config :viban, VibanWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 7777],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "dev_secret_key_base_that_is_at_least_64_bytes_long_for_development_purposes_only",
  watchers: [
    npm: ["run", "dev", cd: Path.expand("../assets", __DIR__)]
  ]

# Enable test endpoints when E2E_TEST=true
config :viban, :env, :dev
config :viban, dev_routes: true

if System.get_env("E2E_TEST") == "true" do
  config :viban, :sandbox_enabled, true
end

if File.exists?(Path.expand("dev.secret.exs", __DIR__)) do
  import_config "dev.secret.exs"
end
