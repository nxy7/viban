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
  # Deploy mode: only for Burrito binaries or explicit VIBAN_DEPLOY_MODE=1
  # This auto-starts Docker Postgres and configures everything for standalone use
  burrito_binary? = String.contains?(__ENV__.file, ".burrito/")
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

  # VB_DATABASE_URL for explicit config, DATABASE_URL as fallback for standard releases
  # Deploy mode uses localhost:17777 (Docker Postgres started by the binary)
  database_url =
    System.get_env("VB_DATABASE_URL") ||
      System.get_env("DATABASE_URL") ||
      if(deploy_mode?, do: "postgres://viban:viban@localhost:17777/viban_prod")

  if is_nil(database_url) do
    raise "DATABASE_URL or VB_DATABASE_URL must be set for non-deploy-mode releases"
  end

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") || 64 |> :crypto.strong_rand_bytes() |> Base.encode64()

  host = System.get_env("PHX_HOST") || "localhost"
  port = String.to_integer(System.get_env("PORT") || if(deploy_mode?, do: "7777", else: "4000"))

  # SSL certificates for HTTPS (enables HTTP/2 for Electric SQL sync)
  # In deploy mode, certs are stored in ~/.viban/cert and generated if missing
  cert_dir =
    if deploy_mode? do
      Path.expand("~/.viban/cert")
    else
      case :code.priv_dir(:viban) do
        {:error, _} -> "priv/cert"
        path -> Path.join(to_string(path), "cert")
      end
    end

  full_cert_path = System.get_env("SSL_CERT_PATH") || Path.join(cert_dir, "selfsigned.pem")
  full_key_path = System.get_env("SSL_KEY_PATH") || Path.join(cert_dir, "selfsigned_key.pem")

  # Generate self-signed certs in deploy mode if they don't exist
  if deploy_mode? and not (File.exists?(full_cert_path) and File.exists?(full_key_path)) do
    File.mkdir_p!(cert_dir)

    if System.find_executable("openssl") do
      System.cmd(
        "openssl",
        [
          "req",
          "-x509",
          "-newkey",
          "rsa:2048",
          "-keyout",
          full_key_path,
          "-out",
          full_cert_path,
          "-sha256",
          "-days",
          "365",
          "-nodes",
          "-subj",
          "/CN=localhost",
          "-addext",
          "subjectAltName=DNS:localhost,IP:127.0.0.1"
        ],
        stderr_to_stdout: true
      )
    end
  end

  use_https = File.exists?(full_cert_path) && File.exists?(full_key_path)

  # In deploy mode, always start the server (no need for PHX_SERVER env var)
  server_enabled? = deploy_mode? or System.get_env("PHX_SERVER") != nil

  config :viban, Viban.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6

  # HTTPS mode - enables HTTP/2 for multiplexed connections (needed for Electric SQL)
  config :viban, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  if use_https do
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
