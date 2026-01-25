defmodule Viban.VCS do
  @moduledoc """
  VCS (Version Control System) dispatcher module.

  This module provides a unified interface for working with different
  git hosting providers (GitHub, GitLab, etc.). It delegates calls
  to the appropriate provider implementation based on the provider atom.

  ## Supported Providers

  - `:github` - GitHub.com
  - `:gitlab` - GitLab.com (planned)

  ## Example

      # List repos for a GitHub user
      Viban.VCS.list_repos(:github, token)

      # Create a pull request
      Viban.VCS.create_pull_request(:github, token, "owner", "repo", %{
        title: "My PR",
        head: "feature-branch",
        base: "main"
      })
  """

  @type provider :: :github | :gitlab
  @type token :: String.t()

  @doc """
  Returns the provider module for the given provider atom.
  """
  @spec provider_module(provider) :: module()
  def provider_module(:github), do: Viban.VCS.GitHub
  # def provider_module(:gitlab), do: Viban.VCS.GitLab

  @doc """
  Lists repositories accessible to the authenticated user.
  """
  @spec list_repos(provider, token, keyword()) :: {:ok, [map()]} | {:error, term()}
  def list_repos(provider, token, opts \\ []) do
    provider_module(provider).list_repos(token, opts)
  end

  @doc """
  Gets a single repository by owner and name.
  """
  @spec get_repo(provider, token, String.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def get_repo(provider, token, owner, repo_name) do
    provider_module(provider).get_repo(token, owner, repo_name)
  end

  @doc """
  Lists branches for a repository.
  """
  @spec list_branches(provider, token, String.t(), String.t(), keyword()) ::
          {:ok, [map()]} | {:error, term()}
  def list_branches(provider, token, owner, repo_name, opts \\ []) do
    provider_module(provider).list_branches(token, owner, repo_name, opts)
  end

  @doc """
  Clones a repository to a local path.
  """
  @spec clone_repo(provider, token, String.t(), String.t()) ::
          {:ok, String.t()} | {:error, term()}
  def clone_repo(provider, token, clone_url, local_path) do
    provider_module(provider).clone_repo(token, clone_url, local_path)
  end

  @doc """
  Creates a new pull request.

  ## Params

    - `:title` - PR title (required)
    - `:body` - PR description (optional)
    - `:head` - The branch containing the changes (required)
    - `:base` - The branch to merge into (required)
  """
  @spec create_pull_request(provider, token, String.t(), String.t(), map()) ::
          {:ok, map()} | {:error, term()}
  def create_pull_request(provider, token, owner, repo_name, params) do
    provider_module(provider).create_pull_request(token, owner, repo_name, params)
  end

  @doc """
  Gets a single pull request by number.
  """
  @spec get_pull_request(provider, token, String.t(), String.t(), integer() | String.t()) ::
          {:ok, map()} | {:error, term()}
  def get_pull_request(provider, token, owner, repo_name, pr_id) do
    provider_module(provider).get_pull_request(token, owner, repo_name, pr_id)
  end

  @doc """
  Lists pull requests for a repository.

  ## Options

    - `:state` - Filter by state: "open", "closed", "all" (default: "open")
    - `:per_page` - Number of results per page (default: 30)
    - `:page` - Page number (default: 1)
  """
  @spec list_pull_requests(provider, token, String.t(), String.t(), keyword()) ::
          {:ok, [map()]} | {:error, term()}
  def list_pull_requests(provider, token, owner, repo_name, opts \\ []) do
    provider_module(provider).list_pull_requests(token, owner, repo_name, opts)
  end

  @doc """
  Updates an existing pull request.

  ## Params (all optional)

    - `:title` - New PR title
    - `:body` - New PR description
    - `:state` - New state: "open" or "closed"
  """
  @spec update_pull_request(
          provider,
          token,
          String.t(),
          String.t(),
          integer() | String.t(),
          map()
        ) ::
          {:ok, map()} | {:error, term()}
  def update_pull_request(provider, token, owner, repo_name, pr_id, params) do
    provider_module(provider).update_pull_request(token, owner, repo_name, pr_id, params)
  end

  @doc """
  Creates a comment on a pull request.
  """
  @spec create_pr_comment(
          provider,
          token,
          String.t(),
          String.t(),
          integer() | String.t(),
          String.t()
        ) ::
          {:ok, map()} | {:error, term()}
  def create_pr_comment(provider, token, owner, repo_name, pr_id, body) do
    provider_module(provider).create_pr_comment(token, owner, repo_name, pr_id, body)
  end

  @doc """
  Lists comments on a pull request.
  """
  @spec list_pr_comments(provider, token, String.t(), String.t(), integer() | String.t()) ::
          {:ok, [map()]} | {:error, term()}
  def list_pr_comments(provider, token, owner, repo_name, pr_id) do
    provider_module(provider).list_pr_comments(token, owner, repo_name, pr_id)
  end

  @doc """
  Gets the authenticated user's information.
  """
  @spec get_user(provider, token) :: {:ok, map()} | {:error, term()}
  def get_user(provider, token) do
    provider_module(provider).get_user(token)
  end

  @doc """
  Parses a full repository name into owner and repo parts.
  Returns {:ok, {owner, repo}} or {:error, :invalid_format}.

  ## Examples

      iex> Viban.VCS.parse_full_name("owner/repo")
      {:ok, {"owner", "repo"}}

      iex> Viban.VCS.parse_full_name("invalid")
      {:error, :invalid_format}
  """
  @spec parse_full_name(String.t()) :: {:ok, {String.t(), String.t()}} | {:error, :invalid_format}
  def parse_full_name(full_name) do
    case String.split(full_name, "/", parts: 2) do
      [owner, repo] when owner != "" and repo != "" ->
        {:ok, {owner, repo}}

      _ ->
        {:error, :invalid_format}
    end
  end
end
