defmodule Viban.DeployMode do
  @moduledoc """
  Handles deploy mode auto-configuration and Docker Postgres management.

  Deploy mode is detected when running from a Burrito-wrapped binary
  or when VIBAN_DEPLOY_MODE=1 is set.
  """

  @data_dir Path.expand("~/.viban")
  @postgres_container "viban-postgres"
  @postgres_port 17777
  @postgres_user "viban"
  @postgres_password "viban"
  @postgres_db "viban_prod"
  @app_port 7777

  def enabled? do
    System.get_env("VIBAN_DEPLOY_MODE") == "1" or burrito_binary?()
  end

  defp burrito_binary? do
    # Burrito extracts to ~/.burrito/ or "Application Support/.burrito/"
    # Check if we're running from such a directory
    case :code.priv_dir(:viban) do
      {:error, _} ->
        false

      priv_dir ->
        path = to_string(priv_dir)
        String.contains?(path, ".burrito/")
    end
  end

  def data_dir, do: @data_dir

  def database_url do
    "postgres://#{@postgres_user}:#{@postgres_password}@localhost:#{@postgres_port}/#{@postgres_db}"
  end

  def app_port, do: @app_port
  def postgres_port, do: @postgres_port

  def ensure_data_dir! do
    log_status("📁", "Data directory: #{@data_dir}")
    File.mkdir_p!(Path.join(@data_dir, "postgres_data"))
    File.mkdir_p!(Path.join(@data_dir, "logs"))
  end

  def ensure_postgres_running! do
    ensure_docker_available!()

    case container_status() do
      :running ->
        log_success("✅", "PostgreSQL already running")

      :stopped ->
        log_status("🐘", "Starting PostgreSQL container...")
        start_container()
        wait_for_postgres()

      :not_found ->
        log_status("🐘", "Creating PostgreSQL container...")
        create_container()
        wait_for_postgres()
    end
  end

  defp ensure_docker_available! do
    case System.find_executable("docker") do
      nil ->
        log_error("❌", "Docker not found!")

        IO.puts("""

        #{IO.ANSI.red()}Viban requires Docker to run in deploy mode.#{IO.ANSI.reset()}

        Please install Docker:
          - macOS: https://docs.docker.com/desktop/install/mac-install/
          - Linux: https://docs.docker.com/engine/install/
          - Windows: https://docs.docker.com/desktop/install/windows-install/

        After installing Docker, make sure it's running and try again.
        """)

        System.halt(1)

      _path ->
        case System.cmd("docker", ["info"], stderr_to_stdout: true) do
          {_, 0} ->
            :ok

          {output, _} ->
            log_error("❌", "Docker is not running!")

            IO.puts("""

            #{IO.ANSI.red()}Docker is installed but not running.#{IO.ANSI.reset()}

            Please start Docker and try again.

            Error: #{String.slice(output, 0, 200)}
            """)

            System.halt(1)
        end
    end
  end

  def ensure_secrets! do
    config_path = Path.join(@data_dir, "config.env")

    if File.exists?(config_path) do
      load_config_env(config_path)
    else
      log_status("🔐", "Generating secrets...")
      secret_key_base = :crypto.strong_rand_bytes(64) |> Base.encode64()

      content = """
      SECRET_KEY_BASE=#{secret_key_base}
      """

      File.write!(config_path, content)
      load_config_env(config_path)
      log_success("✅", "Secrets generated")
    end
  end

  defp container_status do
    case System.cmd(
           "docker",
           ["ps", "-a", "--filter", "name=^#{@postgres_container}$", "--format", "{{.Status}}"],
           stderr_to_stdout: true
         ) do
      {"", 0} ->
        :not_found

      {status, 0} ->
        if String.contains?(status, "Up") do
          :running
        else
          :stopped
        end

      _ ->
        :not_found
    end
  end

  defp create_container do
    postgres_data = Path.join(@data_dir, "postgres_data")

    {output, exit_code} =
      System.cmd(
        "docker",
        [
          "run",
          "-d",
          "--name",
          @postgres_container,
          "-e",
          "POSTGRES_USER=#{@postgres_user}",
          "-e",
          "POSTGRES_PASSWORD=#{@postgres_password}",
          "-e",
          "POSTGRES_DB=#{@postgres_db}",
          "-v",
          "#{postgres_data}:/var/lib/postgresql/data",
          "-p",
          "#{@postgres_port}:5432",
          "postgres:16-alpine",
          "-c",
          "wal_level=logical",
          "-c",
          "max_wal_senders=10",
          "-c",
          "max_replication_slots=10"
        ],
        stderr_to_stdout: true
      )

    if exit_code != 0 do
      raise "Failed to create PostgreSQL container: #{output}"
    end
  end

  defp start_container do
    {output, exit_code} =
      System.cmd("docker", ["start", @postgres_container], stderr_to_stdout: true)

    if exit_code != 0 do
      raise "Failed to start PostgreSQL container: #{output}"
    end
  end

  def stop_postgres do
    if enabled?() do
      case container_status() do
        :running ->
          log_status("🐘", "Stopping PostgreSQL container...")
          {_, _} = System.cmd("docker", ["stop", @postgres_container], stderr_to_stdout: true)
          log_success("✅", "PostgreSQL stopped")

        _ ->
          :ok
      end
    end
  end

  defp wait_for_postgres(attempts \\ 30) do
    log_waiting("Waiting for database... (#{31 - attempts}s)")

    case System.cmd("docker", ["exec", @postgres_container, "pg_isready", "-U", @postgres_user],
           stderr_to_stdout: true
         ) do
      {_, 0} ->
        IO.puts("")
        log_success("✅", "PostgreSQL ready!")
        :ok

      _ when attempts > 0 ->
        Process.sleep(1000)
        wait_for_postgres(attempts - 1)

      _ ->
        IO.puts("")
        raise "PostgreSQL failed to start after 30 seconds"
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

  defp log_error(emoji, message) do
    IO.puts("#{emoji}  #{IO.ANSI.red()}#{message}#{IO.ANSI.reset()}")
  end

  defp log_waiting(message) do
    IO.write("\r#{IO.ANSI.yellow()}⏳ #{message}#{IO.ANSI.reset()}")
  end
end
