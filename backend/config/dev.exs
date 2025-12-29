import Config

config :viban, Viban.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "viban_dev",
  port: 5432,
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :viban, VibanWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 7771],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base:
    "dev_secret_key_base_that_is_at_least_64_bytes_long_for_development_purposes_only",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:viban, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:viban, ~w(--watch)]}
  ]

config :viban, VibanWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/viban_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

config :viban, dev_routes: true

config :logger, :console, format: "[$level] $message\n"

config :phoenix, :stacktrace_depth, 20

config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  debug_heex_annotations: true,
  enable_expensive_runtime_checks: true

# Import secrets if they exist (GitHub OAuth credentials)
if File.exists?(Path.expand("dev.secret.exs", __DIR__)) do
  import_config "dev.secret.exs"
end
