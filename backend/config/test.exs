import Config

# Ash testing configuration
# Disable async operations during tests to work with transactional testing
config :ash, :disable_async?, true
# Ignore missed notifications since tests run in database transactions
config :ash, :missed_notifications, :ignore

# Suppress Electric Phoenix logging during tests
config :logger, :console,
  metadata: [:request_id],
  level: :none

# Configure per-module log levels to suppress noisy test output
config :logger, :default_handler, level: :none

# Suppress logging during tests - can be overridden per-test with @tag :log
config :logger, level: :none

config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Disable Oban during tests to prevent DB connection issues
config :viban, Oban, testing: :inline

config :viban, Viban.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "viban_test#{System.get_env("MIX_TEST_PARTITION")}",
  port: 5432,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

config :viban, VibanWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "test_secret_key_base_that_is_at_least_64_bytes_long_for_testing_purposes_only_here",
  server: false

# Disable auto-migration during tests (mix test runs migrations separately)
config :viban, auto_migrate: false

# Disable BoardManager during tests - it tries to load boards before sandbox is ready
config :viban, start_board_manager: false
