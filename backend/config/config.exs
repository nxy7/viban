import Config

config :ash,
  include_embedded_source_by_default?: false,
  default_page_type: :keyset,
  policies: [no_filter_static_forbidden_reads?: false],
  known_types: [],
  # Hook.id is UUID but ColumnHook.hook_id is String (to support system hooks like "system:refine-prompt")
  compatible_foreign_key_types: [{Ash.Type.UUID, Ash.Type.String}]

config :ash_sync,
  skip: [:query, :ingest],
  output_dir: "../frontend/src/lib/generated/sync"

config :ash_typescript,
  output_file: "../frontend/src/lib/generated/ash.ts",
  run_endpoint: "/api/rpc/run",
  validate_endpoint: "/api/rpc/validate",
  output_field_formatter: :snake_case,
  input_field_formatter: :snake_case,
  rpc_action_after_request_hook: "RpcHooks.afterActionRequest",
  import_into_generated: [
    %{
      import_name: "RpcHooks",
      file: "../rpcHooks"
    }
  ]

config :esbuild,
  version: "0.17.11",
  viban: [
    args: ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :task_id]

config :phoenix, :json_library, Jason

config :phoenix_sync,
  env: Mix.env(),
  mode: :embedded

# Disable swoosh API client (we don't need email for now)
config :swoosh, :api_client, false

config :tailwind,
  version: "3.4.3",
  viban: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Oban job queue configuration
config :viban, Oban,
  repo: Viban.Repo,
  queues: [
    default: 10,
    generate_subtasks: 3
  ],
  plugins: [
    Oban.Plugins.Pruner,
    {Oban.Plugins.Lifeline, rescue_after: to_timeout(minute: 30)},
    {Oban.Plugins.Cron,
     crontab: [
       {"0 3 * * *", Viban.Workers.WorktreeCleanupWorker},
       {"* * * * *", Viban.Workers.PRSyncWorker}
     ]}
  ]

config :viban, Viban.Repo,
  migration_primary_key: [type: :uuid],
  migration_timestamps: [type: :utc_datetime_usec]

config :viban, Viban.RepoSqlite,
  database: Path.expand("~/.viban/viban.db"),
  pool_size: 1,
  journal_mode: :wal,
  cache_size: -64000,
  temp_store: :memory,
  busy_timeout: 5000

config :viban, VibanWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: VibanWeb.ErrorHTML, json: VibanWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Viban.PubSub,
  live_view: [signing_salt: "viban_salt_12345"]

# GitHub Device Flow OAuth
# The client ID is loaded from GH_CLIENT_ID env var in runtime.exs
# Device Flow doesn't require a client secret - only the public client ID
config :viban, :github_client_id, nil

config :viban,
  ecto_repos: [Viban.Repo, Viban.RepoSqlite],
  generators: [timestamp_type: :utc_datetime],
  ash_domains: [
    Viban.Messages,
    Viban.Kanban,
    Viban.KanbanLite,
    Viban.Accounts,
    Viban.Executors,
    Viban.AppRuntime,
    Viban.StateServer
  ],
  # Store cloned repos in ~/.local/share/viban/repos
  repos_base_path: Path.expand("~/.local/share/viban/repos"),
  # Store worktrees in ~/.local/share/viban/worktrees (persistent, not tmpfs)
  worktree_base_path: Path.expand("~/.local/share/viban/worktrees"),
  # Worktree TTL in days for Done/Cancelled tasks (default: 7)
  worktree_ttl_days: 7

import_config "#{config_env()}.exs"
