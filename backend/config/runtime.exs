import Config

if System.get_env("PHX_SERVER") do
  config :viban, VibanWeb.Endpoint, server: true
end

# GitHub OAuth credentials
gh_client_id = System.get_env("GH_CLIENT_ID")
gh_client_secret = System.get_env("GH_CLIENT_SECRET")

if gh_client_id && gh_client_secret do
  config :ueberauth, Ueberauth.Strategy.Github.OAuth,
    client_id: gh_client_id,
    client_secret: gh_client_secret
end

# LLM API Keys (available in all environments)
if api_key = System.get_env("ANTHROPIC_API_KEY") do
  config :viban, anthropic_api_key: api_key
end

# Future provider keys
# if api_key = System.get_env("OPENAI_API_KEY") do
#   config :viban, openai_api_key: api_key
# end

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :viban, Viban.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :viban, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :viban, VibanWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base
end
