defmodule Viban.CLI do
  @moduledoc """
  CLI argument handling for Viban.

  Handles --help, --version and other flags before the application starts.
  """

  @version Mix.Project.config()[:version]

  def run do
    args = Burrito.Util.Args.argv()

    cond do
      "--help" in args or "-h" in args ->
        print_help()
        System.halt(0)

      "--version" in args or "-v" in args ->
        print_version()
        System.halt(0)

      true ->
        :ok
    end
  end

  defp print_version do
    IO.puts("viban #{@version}")
  end

  defp print_help do
    IO.puts("""
    Viban - Fast-iteration task management tool

    Usage: viban [options]

    Options:
      -h, --help      Show this help message
      -v, --version   Show version information

    Environment Variables:
      VIBAN_DEPLOY_MODE=1   Force deploy mode (auto-start Postgres, etc.)
      DATABASE_URL          PostgreSQL connection URL
      SECRET_KEY_BASE       Phoenix secret key (auto-generated in deploy mode)
      PORT                  Server port (default: 8000 in deploy mode, 4000 otherwise)
      E2E_TEST=true         Enable test endpoints for E2E testing

    Deploy Mode:
      When running as a Burrito binary or with VIBAN_DEPLOY_MODE=1, Viban will:
      - Automatically start a PostgreSQL Docker container
      - Store data in ~/.viban/
      - Run database migrations on startup
      - Generate secrets if needed

    Examples:
      ./viban                    # Start in deploy mode (auto-detects Burrito)
      ./viban --version          # Show version
      VIBAN_DEPLOY_MODE=1 ./viban   # Force deploy mode

    More info: https://github.com/your-repo/viban
    """)
  end
end
