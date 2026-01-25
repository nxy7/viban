defmodule Viban.AppRuntime.AppUpdates.Github do
  @moduledoc """
  GitHub API interactions for update checking.
  """

  require Logger

  @github_repo "nxy7/viban"
  @github_api_url "https://api.github.com"

  @type release :: %{
          tag_name: String.t(),
          html_url: String.t(),
          assets: [%{name: String.t(), browser_download_url: String.t()}]
        }

  @spec fetch_latest_release() :: {:ok, release()} | {:error, term()}
  def fetch_latest_release do
    url = "#{@github_api_url}/repos/#{@github_repo}/releases/latest"

    case Req.get(url, headers: [{"user-agent", "viban-updater"}, {"accept", "application/vnd.github.v3+json"}]) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: 404}} ->
        {:error, :no_releases}

      {:ok, %{status: 403}} ->
        {:error, :rate_limited}

      {:ok, %{status: status}} ->
        {:error, {:github_api_error, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec compare_versions(String.t(), String.t()) :: :newer | :same | :older
  def compare_versions(current, latest) do
    current_normalized = normalize_version(current)
    latest_normalized = normalize_version(latest)

    case Version.compare(current_normalized, latest_normalized) do
      :lt -> :newer
      :eq -> :same
      :gt -> :older
    end
  rescue
    _ -> :same
  end

  @spec parse_assets(release()) :: %{atom() => String.t()}
  def parse_assets(release) do
    tag = release["tag_name"]
    assets = release["assets"] || []

    platforms = [:macos_arm, :macos_intel, :linux_intel, :linux_arm]

    Enum.reduce(platforms, %{}, fn platform, acc ->
      asset_name = "viban-#{tag}-#{platform}"

      case Enum.find(assets, fn a -> a["name"] == asset_name end) do
        nil -> acc
        asset -> Map.put(acc, platform, asset["browser_download_url"])
      end
    end)
  end

  defp normalize_version(version) do
    version
    |> String.trim_leading("v")
    |> ensure_valid_semver()
  end

  defp ensure_valid_semver(version) do
    parts = String.split(version, ".")

    case length(parts) do
      1 -> version <> ".0.0"
      2 -> version <> ".0"
      _ -> version
    end
  end
end
