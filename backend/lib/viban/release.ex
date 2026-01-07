defmodule Viban.Release do
  @moduledoc """
  Release tasks for production deployments.
  """

  @app :viban

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  def setup do
    ensure_ssl_certs()
    migrate()
  end

  def ensure_ssl_certs do
    cert_dir = cert_directory()
    cert_path = Path.join(cert_dir, "selfsigned.pem")
    key_path = Path.join(cert_dir, "selfsigned_key.pem")

    if File.exists?(cert_path) && File.exists?(key_path) do
      IO.puts("SSL certificates already exist at #{cert_dir}")
      :ok
    else
      IO.puts("Generating self-signed SSL certificates for HTTP/2 support...")
      File.mkdir_p!(cert_dir)
      generate_self_signed_cert(cert_path, key_path)
      IO.puts("SSL certificates generated at #{cert_dir}")
      :ok
    end
  end

  defp generate_self_signed_cert(cert_path, key_path) do
    # Generate using openssl (available on most systems)
    subject = "/C=US/ST=Local/L=Local/O=Viban/CN=localhost"

    {_, 0} =
      System.cmd(
        "openssl",
        [
          "req",
          "-x509",
          "-newkey",
          "rsa:4096",
          "-keyout",
          key_path,
          "-out",
          cert_path,
          "-sha256",
          "-days",
          "365",
          "-nodes",
          "-subj",
          subject,
          "-addext",
          "subjectAltName=DNS:localhost,IP:127.0.0.1"
        ],
        stderr_to_stdout: true
      )
  end

  def cert_directory do
    if Viban.DeployMode.enabled?() do
      Path.expand("~/.viban/cert")
    else
      case :code.priv_dir(@app) do
        {:error, _} -> "priv/cert"
        path -> Path.join(to_string(path), "cert")
      end
    end
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end
end
