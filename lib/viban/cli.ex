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
      SECRET_KEY_BASE       Phoenix secret key (auto-generated if not set)
      PORT                  Server port (default: 7777)
      E2E_TEST=true         Enable test endpoints for E2E testing

    Data Storage:
      Viban uses SQLite and stores data in ~/.viban/viban.db

    Examples:
      ./viban                    # Start the server
      ./viban --version          # Show version

    More info: https://github.com/nxy7/viban
    """)
  end
end
