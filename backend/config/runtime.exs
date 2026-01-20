import Config

if System.get_env("PHX_SERVER") do
  config :viban, VibanWeb.Endpoint, server: true
end

# GitHub Device Flow OAuth (no secret required)
if gh_client_id = System.get_env("GH_CLIENT_ID") do
  config :viban, :github_client_id, gh_client_id
end

# LLM API Keys (available in all environments)
if api_key = System.get_env("ANTHROPIC_API_KEY") do
  config :viban, anthropic_api_key: api_key
end

# Future provider keys
# if api_key = System.get_env("OPENAI_API_KEY") do
#   config :viban, openai_api_key: api_key
# end

# Enable test endpoints when E2E_TEST=true (works in all environments)
if System.get_env("E2E_TEST") == "true" do
  config :logger, level: :warning

  config :viban, :sandbox_enabled, true
end

if config_env() == :prod do
  # Deploy mode detection - Burrito binaries extract to a path containing ".burrito/"
  env_file = __ENV__.file
  release_root = System.get_env("RELEASE_ROOT") || ""

  burrito_binary? =
    String.contains?(env_file, ".burrito/") or
      String.contains?(release_root, ".burrito/")

  explicit_deploy_mode? = System.get_env("VIBAN_DEPLOY_MODE") == "1"

  deploy_mode? = explicit_deploy_mode? or burrito_binary?

  # In deploy mode, load config from ~/.viban/config.env if it exists
  if deploy_mode? do
    config_path = Path.expand("~/.viban/config.env")

    if File.exists?(config_path) do
      config_path
      |> File.read!()
      |> String.split("\n", trim: true)
      |> Enum.each(fn line ->
        case String.split(line, "=", parts: 2) do
          [key, value] -> System.put_env(String.trim(key), String.trim(value))
          _ -> :ok
        end
      end)
    end
  end

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") || 64 |> :crypto.strong_rand_bytes() |> Base.encode64()

  host = System.get_env("PHX_HOST") || "localhost"
  port = String.to_integer(System.get_env("PORT") || "7777")

  # In deploy mode, always start the server (no need for PHX_SERVER env var)
  server_enabled? = deploy_mode? or System.get_env("PHX_SERVER") != nil

  # SQLite database path - uses ~/.viban/viban.db in deploy mode
  sqlite_db_path =
    System.get_env("VIBAN_DB_PATH") || Path.expand("~/.viban/viban.db")

  config :viban, Viban.RepoSqlite, database: sqlite_db_path

  config :viban, VibanWeb.Endpoint,
    server: server_enabled?,
    url: [host: host, port: port, scheme: "http"],
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

  config :viban, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")
end
