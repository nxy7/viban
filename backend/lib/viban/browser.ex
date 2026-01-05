defmodule Viban.Browser do
  @moduledoc """
  Handles automatic browser opening on application startup in deploy mode.

  Opens the backend URL (http://localhost:7777) when running as a Burrito binary.
  Can be disabled with VIBAN_NO_BROWSER=1 environment variable.
  """

  require Logger

  def open do
    if should_open?() do
      url = get_url()
      spawn(fn -> do_open(url) end)
    end
  end

  defp should_open? do
    # Only open browser in deploy mode (Burrito binary)
    # In dev, the user runs overmind which doesn't need auto-open
    # Can be disabled with VIBAN_NO_BROWSER=1
    Viban.DeployMode.enabled?() and System.get_env("VIBAN_NO_BROWSER") != "1"
  end

  defp get_url do
    port = Viban.DeployMode.app_port()
    "http://localhost:#{port}"
  end

  defp do_open(url) do
    # Wait a moment for the endpoint to be fully ready
    Process.sleep(500)

    case :os.type() do
      {:unix, :darwin} ->
        System.cmd("open", [url], stderr_to_stdout: true)

      {:unix, _} ->
        # Try xdg-open first (most Linux distros), fall back to alternatives
        cond do
          System.find_executable("xdg-open") ->
            System.cmd("xdg-open", [url], stderr_to_stdout: true)

          System.find_executable("gnome-open") ->
            System.cmd("gnome-open", [url], stderr_to_stdout: true)

          System.find_executable("kde-open") ->
            System.cmd("kde-open", [url], stderr_to_stdout: true)

          true ->
            Logger.info("Could not find browser opener. Visit: #{url}")
        end

      {:win32, _} ->
        System.cmd("cmd", ["/c", "start", url], stderr_to_stdout: true)

      _ ->
        Logger.info("Unknown OS. Visit: #{url}")
    end

    Logger.info("🌐 Opened browser at #{url}")
  end
end
