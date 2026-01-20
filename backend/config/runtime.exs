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

  external_database_url = System.get_env("VB_DATABASE_URL") || System.get_env("DATABASE_URL")
  using_external_database? = external_database_url != nil

  database_url =
    external_database_url ||
      if(deploy_mode?, do: "postgres://viban:viban@localhost:17777/viban_prod")

  if is_nil(database_url) do
    raise "DATABASE_URL or VB_DATABASE_URL must be set for non-deploy-mode releases"
  end

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") || 64 |> :crypto.strong_rand_bytes() |> Base.encode64()

  host = System.get_env("PHX_HOST") || "localhost"
  port = String.to_integer(System.get_env("PORT") || if(deploy_mode?, do: "7777", else: "4000"))

  # In deploy mode, always start the server (no need for PHX_SERVER env var)
  server_enabled? = deploy_mode? or System.get_env("PHX_SERVER") != nil
  db_uri = URI.parse(database_url)
  [db_username, db_password] = String.split(db_uri.userinfo || "postgres:postgres", ":")
  db_name = String.trim_leading(db_uri.path || "/postgres", "/")
  db_port = db_uri.port || 5432

  config :phoenix_sync,
    env: :prod,
    mode: :embedded,
    repo: Viban.Repo

  config :viban, Viban.Repo,
    url: database_url,
    hostname: db_uri.host,
    port: db_port,
    database: db_name,
    username: db_username,
    password: db_password,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6

  config :viban, VibanWeb.Endpoint,
    server: server_enabled?,
    url: [host: host, port: port, scheme: "http"],
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

  config :viban, :database_url, database_url
  config :viban, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")
  config :viban, :using_external_database, using_external_database?
end
