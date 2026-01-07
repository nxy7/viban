defmodule Viban.AppRuntime.AppUpdates do
  @moduledoc """
  Ash Resource for application update management.

  Provides actions to check for updates from GitHub releases and retrieve
  download URLs. Uses AshOban for scheduled hourly checks.
  """

  use Ash.Resource,
    domain: Viban.AppRuntime,
    data_layer: Ash.DataLayer.Simple,
    extensions: [AshTypescript.Resource, AshOban]

  alias Viban.AppRuntime.AppUpdates.Github
  alias Viban.AppRuntime.AppUpdates.State

  require Logger

  typescript do
    type_name("AppUpdates")
  end

  resource do
    require_primary_key? false
  end

  oban do
    scheduled_actions do
      schedule(:hourly_update_check, "0 * * * *",
        action: :check_github,
        max_attempts: 3,
        queue: :default,
        worker_module_name: Viban.Workers.UpdateCheckWorker
      )
    end
  end

  actions do
    action :get_status, :map do
      description "Get current update status including available version"

      run fn _input, _context ->
        state = State.get()
        current = State.current_version()
        latest = state["latest_version"]

        update_available =
          if latest do
            Github.compare_versions(current, latest) == :newer
          else
            false
          end

        {:ok,
         %{
           current_version: current,
           latest_version: latest,
           update_available: update_available,
           release_notes_url: state["release_url"],
           last_check: state["last_check"]
         }}
      end
    end

    action :check_github, :map do
      description "Check GitHub for the latest release and store results"

      run fn _input, _context ->
        if update_check_disabled?() do
          Logger.debug("[AppUpdates] Update check disabled via VIBAN_NO_UPDATE_CHECK")
          {:ok, %{skipped: true}}
        else
          do_check_github()
        end
      end
    end

    action :get_download_url, :map do
      description "Get the download URL for a specific platform"

      argument :platform, :atom do
        allow_nil? true
        constraints one_of: [:macos_arm, :macos_intel, :linux_intel, :linux_arm]
        description "Target platform. If not specified, auto-detects current platform."
      end

      run fn input, _context ->
        state = State.get()
        platform = input.arguments[:platform] || State.platform_target()
        assets = state["assets"] || %{}

        platform_str = to_string(platform)
        url = assets[platform_str]

        {:ok,
         %{
           url: url,
           platform: platform,
           version: state["latest_version"],
           all_platforms: assets
         }}
      end
    end
  end

  code_interface do
    define :get_status
    define :check_github
    define :get_download_url, args: [:platform]
  end

  defp update_check_disabled? do
    System.get_env("VIBAN_NO_UPDATE_CHECK") == "1"
  end

  defp do_check_github do
    case Github.fetch_latest_release() do
      {:ok, release} ->
        current = State.current_version()
        latest = release["tag_name"]
        comparison = Github.compare_versions(current, latest)

        if comparison == :newer do
          assets = Github.parse_assets(release)

          State.put(%{
            "latest_version" => String.trim_leading(latest, "v"),
            "release_url" => release["html_url"],
            "assets" =>
              Map.new(assets, fn {k, v} ->
                {to_string(k), v}
              end)
          })

          Logger.info("[AppUpdates] New version available: #{latest}")
        else
          Logger.debug("[AppUpdates] Already on latest version (#{current})")
        end

        {:ok, %{current: current, latest: latest, comparison: comparison}}

      {:error, :rate_limited} ->
        Logger.warning("[AppUpdates] GitHub rate limit reached, will retry next hour")
        {:ok, %{error: "rate_limited"}}

      {:error, :no_releases} ->
        Logger.debug("[AppUpdates] No releases found on GitHub")
        {:ok, %{error: "no_releases"}}

      {:error, reason} ->
        Logger.warning("[AppUpdates] Failed to check GitHub: #{inspect(reason)}")
        {:ok, %{error: inspect(reason)}}
    end
  end
end
