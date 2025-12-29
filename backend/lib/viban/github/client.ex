defmodule Viban.GitHub.Client do
  @moduledoc """
  GitHub API client for PR operations using the gh CLI.
  """

  require Logger

  @doc """
  Create a pull request.
  Returns {:ok, %{url: url, number: number, status: :open}} on success.
  """
  def create_pr(repo_path, base_branch, head_branch, title, body) do
    args = [
      "pr",
      "create",
      "--base",
      base_branch,
      "--head",
      head_branch,
      "--title",
      title,
      "--body",
      body
    ]

    case run_gh(args, repo_path) do
      {:ok, output} ->
        pr_url = String.trim(output)
        pr_number = extract_pr_number(pr_url)
        {:ok, %{url: pr_url, number: pr_number, status: :open}}

      {:error, error} ->
        Logger.error("[GitHub.Client] Failed to create PR: #{error}")
        {:error, error}
    end
  end

  @doc """
  Find existing PR for a branch.
  Returns {:ok, nil} if no PR found, {:ok, %{url, number, status}} if found.
  """
  def find_pr_for_branch(repo_path, branch_name) do
    args = [
      "pr",
      "list",
      "--head",
      branch_name,
      "--json",
      "number,url,state,isDraft",
      "--limit",
      "1"
    ]

    case run_gh(args, repo_path) do
      {:ok, output} ->
        case Jason.decode(output) do
          {:ok, [pr | _]} ->
            {:ok,
             %{
               url: pr["url"],
               number: pr["number"],
               status: parse_pr_status(pr["state"], pr["isDraft"])
             }}

          {:ok, []} ->
            {:ok, nil}

          {:error, _} ->
            {:error, "Failed to parse PR data"}
        end

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Get PR status by number.
  """
  def get_pr_status(repo_path, pr_number) do
    args = [
      "pr",
      "view",
      to_string(pr_number),
      "--json",
      "state,isDraft,merged"
    ]

    case run_gh(args, repo_path) do
      {:ok, output} ->
        case Jason.decode(output) do
          {:ok, pr} ->
            {:ok, parse_pr_status(pr["state"], pr["isDraft"], pr["merged"])}

          {:error, _} ->
            {:error, "Failed to parse PR status"}
        end

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Check if a PR is merged.
  """
  def is_merged?(repo_path, pr_number) do
    case get_pr_status(repo_path, pr_number) do
      {:ok, :merged} -> true
      _ -> false
    end
  end

  # Run gh CLI command in the specified directory
  defp run_gh(args, working_directory) do
    opts = [cd: working_directory, stderr_to_stdout: true]

    case System.cmd("gh", args, opts) do
      {output, 0} ->
        {:ok, output}

      {error, exit_code} ->
        Logger.warning(
          "[GitHub.Client] gh command failed (exit #{exit_code}): #{String.slice(error, 0, 200)}"
        )

        {:error, String.trim(error)}
    end
  end

  defp extract_pr_number(url) do
    case Regex.run(~r/\/pull\/(\d+)/, url) do
      [_, number] -> String.to_integer(number)
      _ -> nil
    end
  end

  defp parse_pr_status(state, is_draft, merged \\ false) do
    cond do
      merged -> :merged
      is_draft -> :draft
      state == "OPEN" -> :open
      state == "CLOSED" -> :closed
      state == "MERGED" -> :merged
      true -> :open
    end
  end
end
