defmodule VibanWeb.VCSController do
  @moduledoc """
  API endpoints for VCS (Version Control System) integration.

  Provides a unified interface for interacting with version control providers
  (GitHub, GitLab, etc.) through the authenticated user's credentials.

  ## Authentication

  All endpoints require authentication. The user's VCS provider and access token
  are automatically used based on their authenticated session.

  ## Endpoints

  - `GET /api/vcs/repos` - List user's repositories
  - `GET /api/vcs/repos/:owner/:repo/branches` - List branches for a repository
  - `GET /api/vcs/repos/:owner/:repo/pulls` - List pull requests
  - `GET /api/vcs/repos/:owner/:repo/pulls/:pr_id` - Get a single pull request
  - `POST /api/vcs/repos/:owner/:repo/pulls` - Create a pull request
  - `PATCH /api/vcs/repos/:owner/:repo/pulls/:pr_id` - Update a pull request
  - `GET /api/vcs/repos/:owner/:repo/pulls/:pr_id/comments` - List PR comments
  - `POST /api/vcs/repos/:owner/:repo/pulls/:pr_id/comments` - Create a PR comment
  """

  use VibanWeb, :controller

  import VibanWeb.ControllerHelpers,
    only: [
      require_current_user: 1,
      json_ok: 2,
      json_error: 3,
      handle_vcs_error: 3,
      get_int_param: 3,
      maybe_put: 3
    ]

  alias Viban.VCS

  plug VibanWeb.Plugs.RequireAuth

  # Default pagination values
  @default_repos_per_page 100
  @default_prs_per_page 30
  @default_page 1
  @default_sort "updated"
  @default_pr_state "open"

  @doc """
  Lists repositories for the authenticated user.

  Only returns repositories where the user has push access.

  ## Query Parameters

  - `per_page` - Number of results per page (default: 100)
  - `page` - Page number (default: 1)
  - `sort` - Sort field (default: "updated")
  """
  @spec list_repos(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def list_repos(conn, params) do
    {:ok, user} = require_current_user(conn)

    opts = [
      per_page: get_int_param(params, "per_page", @default_repos_per_page),
      page: get_int_param(params, "page", @default_page),
      sort: Map.get(params, "sort", @default_sort)
    ]

    case VCS.list_repos(user.provider, user.access_token, opts) do
      {:ok, repos} ->
        json_ok(conn, %{repos: repos})

      error ->
        handle_vcs_error(conn, error, "Failed to fetch repositories")
    end
  end

  @doc """
  Gets branches for a specific repository.

  ## Path Parameters

  - `owner` - Repository owner
  - `repo` - Repository name
  """
  @spec list_branches(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def list_branches(conn, %{"owner" => owner, "repo" => repo_name}) do
    {:ok, user} = require_current_user(conn)

    case VCS.list_branches(user.provider, user.access_token, owner, repo_name) do
      {:ok, branches} ->
        json_ok(conn, %{branches: branches})

      error ->
        handle_vcs_error(conn, error, "Failed to fetch branches")
    end
  end

  @doc """
  Lists pull requests for a specific repository.

  ## Path Parameters

  - `owner` - Repository owner
  - `repo` - Repository name

  ## Query Parameters

  - `state` - PR state filter: "open", "closed", "all" (default: "open")
  - `per_page` - Number of results per page (default: 30)
  - `page` - Page number (default: 1)
  """
  @spec list_pull_requests(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def list_pull_requests(conn, %{"owner" => owner, "repo" => repo_name} = params) do
    {:ok, user} = require_current_user(conn)

    opts = [
      state: Map.get(params, "state", @default_pr_state),
      per_page: get_int_param(params, "per_page", @default_prs_per_page),
      page: get_int_param(params, "page", @default_page)
    ]

    case VCS.list_pull_requests(user.provider, user.access_token, owner, repo_name, opts) do
      {:ok, prs} ->
        json_ok(conn, %{pull_requests: prs})

      error ->
        handle_vcs_error(conn, error, "Failed to fetch pull requests")
    end
  end

  @doc """
  Gets a single pull request.

  ## Path Parameters

  - `owner` - Repository owner
  - `repo` - Repository name
  - `pr_id` - Pull request ID
  """
  @spec get_pull_request(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def get_pull_request(conn, %{"owner" => owner, "repo" => repo_name, "pr_id" => pr_id}) do
    {:ok, user} = require_current_user(conn)

    case VCS.get_pull_request(user.provider, user.access_token, owner, repo_name, pr_id) do
      {:ok, pr} ->
        json_ok(conn, %{pull_request: pr})

      error ->
        handle_vcs_error(conn, error, "Failed to fetch pull request")
    end
  end

  @doc """
  Creates a new pull request.

  ## Path Parameters

  - `owner` - Repository owner
  - `repo` - Repository name

  ## Body Parameters

  - `title` - PR title (required)
  - `body` - PR description
  - `head` - Head branch (required)
  - `base` - Base branch (required)
  """
  @spec create_pull_request(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create_pull_request(conn, %{"owner" => owner, "repo" => repo_name} = params) do
    {:ok, user} = require_current_user(conn)

    pr_params = %{
      title: Map.get(params, "title"),
      body: Map.get(params, "body"),
      head: Map.get(params, "head"),
      base: Map.get(params, "base")
    }

    case VCS.create_pull_request(user.provider, user.access_token, owner, repo_name, pr_params) do
      {:ok, pr} ->
        conn
        |> put_status(:created)
        |> json_ok(%{pull_request: pr})

      error ->
        handle_vcs_error(conn, error, "Failed to create pull request")
    end
  end

  @doc """
  Updates a pull request.

  ## Path Parameters

  - `owner` - Repository owner
  - `repo` - Repository name
  - `pr_id` - Pull request ID

  ## Body Parameters (all optional)

  - `title` - New PR title
  - `body` - New PR description
  - `state` - New state ("open" or "closed")
  """
  @spec update_pull_request(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update_pull_request(
        conn,
        %{"owner" => owner, "repo" => repo_name, "pr_id" => pr_id} = params
      ) do
    {:ok, user} = require_current_user(conn)

    pr_params =
      %{}
      |> maybe_put(:title, params["title"])
      |> maybe_put(:body, params["body"])
      |> maybe_put(:state, params["state"])

    case VCS.update_pull_request(
           user.provider,
           user.access_token,
           owner,
           repo_name,
           pr_id,
           pr_params
         ) do
      {:ok, pr} ->
        json_ok(conn, %{pull_request: pr})

      error ->
        handle_vcs_error(conn, error, "Failed to update pull request")
    end
  end

  @doc """
  Creates a comment on a pull request.

  ## Path Parameters

  - `owner` - Repository owner
  - `repo` - Repository name
  - `pr_id` - Pull request ID

  ## Body Parameters

  - `body` - Comment text (required)
  """
  @spec create_pr_comment(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create_pr_comment(conn, %{
        "owner" => owner,
        "repo" => repo_name,
        "pr_id" => pr_id,
        "body" => body
      }) do
    {:ok, user} = require_current_user(conn)

    case VCS.create_pr_comment(user.provider, user.access_token, owner, repo_name, pr_id, body) do
      {:ok, comment} ->
        conn
        |> put_status(:created)
        |> json_ok(%{comment: comment})

      error ->
        handle_vcs_error(conn, error, "Failed to create comment")
    end
  end

  def create_pr_comment(conn, _params) do
    json_error(conn, :bad_request, "Missing required parameter: body")
  end

  @doc """
  Lists comments on a pull request.

  ## Path Parameters

  - `owner` - Repository owner
  - `repo` - Repository name
  - `pr_id` - Pull request ID
  """
  @spec list_pr_comments(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def list_pr_comments(conn, %{"owner" => owner, "repo" => repo_name, "pr_id" => pr_id}) do
    {:ok, user} = require_current_user(conn)

    case VCS.list_pr_comments(user.provider, user.access_token, owner, repo_name, pr_id) do
      {:ok, comments} ->
        json_ok(conn, %{comments: comments})

      error ->
        handle_vcs_error(conn, error, "Failed to fetch comments")
    end
  end
end
