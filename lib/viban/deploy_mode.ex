defmodule Viban.DeployMode do
  @moduledoc """
  Handles deploy mode auto-configuration for single-binary deployment.

  Deploy mode is detected when running from a Burrito-wrapped binary
  or when VIBAN_DEPLOY_MODE=1 is set.

  In deploy mode:
  - SQLite database is stored in ~/.viban/
  - Secrets are auto-generated if not present
  - App opens in browser on startup
  """

  @data_dir Path.expand("~/.viban")
  @app_port 7777

  def enabled? do
    explicit = System.get_env("VIBAN_DEPLOY_MODE") == "1"
    burrito = burrito_binary?()

    result = explicit or burrito

    if System.get_env("VIBAN_DEBUG") == "1" do
      IO.puts("[DeployMode] explicit=#{explicit} burrito=#{burrito} => enabled=#{result}")
      IO.puts("[DeployMode] priv_dir=#{inspect(:code.priv_dir(:viban))}")
    end

    result
  end

  defp burrito_binary? do
    case :code.priv_dir(:viban) do
      {:error, _} ->
        false

      priv_dir ->
        path = to_string(priv_dir)
        String.contains?(path, ".burrito/")
    end
  end

  def data_dir, do: @data_dir
  def app_port, do: @app_port

  def ensure_data_dir! do
    log_status("📁", "Data directory: #{@data_dir}")
    File.mkdir_p!(Path.join(@data_dir, "logs"))
  end

  def ensure_secrets! do
    config_path = Path.join(@data_dir, "config.env")

    if File.exists?(config_path) do
      load_config_env(config_path)
    else
      log_status("🔐", "Generating secrets...")
      secret_key_base = 64 |> :crypto.strong_rand_bytes() |> Base.encode64()

      content = """
      SECRET_KEY_BASE=#{secret_key_base}
      """

      File.write!(config_path, content)
      load_config_env(config_path)
      log_success("✅", "Secrets generated")
    end
  end

  defp load_config_env(path) do
    path
    |> File.read!()
    |> String.split("\n", trim: true)
    |> Enum.each(fn line ->
      case String.split(line, "=", parts: 2) do
        [key, value] ->
          System.put_env(String.trim(key), String.trim(value))

        _ ->
          :ok
      end
    end)
  end

  defp log_status(emoji, message) do
    IO.puts("#{emoji}  #{IO.ANSI.cyan()}#{message}#{IO.ANSI.reset()}")
  end

  defp log_success(emoji, message) do
    IO.puts("#{emoji}  #{IO.ANSI.green()}#{message}#{IO.ANSI.reset()}")
  end
end
