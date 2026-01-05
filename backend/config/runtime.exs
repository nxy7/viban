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
  config :viban, :sandbox_enabled, true
end

if config_env() == :prod do
  # Detect deploy mode: explicit env var, running from Burrito, or no DATABASE_URL provided
  # When no config is given, default to deploy mode so the binary "just works"
  burrito_binary? = String.contains?(__ENV__.file, ".burrito/")
  explicit_deploy_mode? = System.get_env("VIBAN_DEPLOY_MODE") == "1"
  has_database_url? = System.get_env("DATABASE_URL") != nil

  deploy_mode? = explicit_deploy_mode? or burrito_binary? or not has_database_url?

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

  database_url =
    System.get_env("DATABASE_URL") || "postgres://viban:viban@localhost:17777/viban_prod"

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :viban, Viban.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") || :crypto.strong_rand_bytes(64) |> Base.encode64()

  host = System.get_env("PHX_HOST") || "localhost"
  port = String.to_integer(System.get_env("PORT") || if(deploy_mode?, do: "7777", else: "4000"))

  config :viban, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  # Check for SSL cert files (enables HTTP/2 for better Electric sync performance)
  cert_path = System.get_env("SSL_CERT_PATH") || "priv/cert/selfsigned.pem"
  key_path = System.get_env("SSL_KEY_PATH") || "priv/cert/selfsigned_key.pem"

  priv_dir =
    case :code.priv_dir(:viban) do
      {:error, _} -> "priv"
      path -> to_string(path)
    end

  full_cert_path =
    if String.starts_with?(cert_path, "/"),
      do: cert_path,
      else: Path.join(priv_dir, String.replace_prefix(cert_path, "priv/", ""))

  full_key_path =
    if String.starts_with?(key_path, "/"),
      do: key_path,
      else: Path.join(priv_dir, String.replace_prefix(key_path, "priv/", ""))

  use_https = File.exists?(full_cert_path) && File.exists?(full_key_path)

  # In deploy mode, always start the server (no need for PHX_SERVER env var)
  server_enabled? = deploy_mode? or System.get_env("PHX_SERVER") != nil

  if use_https do
    # HTTPS mode - enables HTTP/2 for multiplexed connections (needed for Electric SQL)
    config :viban, VibanWeb.Endpoint,
      server: server_enabled?,
      url: [host: host, port: port, scheme: "https"],
      https: [
        ip: {0, 0, 0, 0, 0, 0, 0, 0},
        port: port,
        cipher_suite: :strong,
        certfile: full_cert_path,
        keyfile: full_key_path
      ],
      secret_key_base: secret_key_base
  else
    # HTTP mode - fallback if no certs
    config :viban, VibanWeb.Endpoint,
      server: server_enabled?,
      url: [host: host, port: port, scheme: "http"],
      http: [
        ip: {0, 0, 0, 0, 0, 0, 0, 0},
        port: port
      ],
      secret_key_base: secret_key_base
  end
end
