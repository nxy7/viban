defmodule Viban.VCS.GitHub do
  @moduledoc """
  GitHub implementation of the VCS Provider behaviour.

  Uses the user's OAuth access token for authentication.
  All API calls are made to the GitHub REST API v3.
  """

  @behaviour Viban.VCS.Provider

  @github_api_url "https://api.github.com"

  # Repository operations

  @impl true
  def list_repos(access_token, opts \\ []) do
    params = [
      per_page: Keyword.get(opts, :per_page, 100),
      page: Keyword.get(opts, :page, 1),
      sort: Keyword.get(opts, :sort, "updated"),
      type: Keyword.get(opts, :type, "all")
    ]

    case get("/user/repos", access_token, params: params) do
      {:ok, repos} ->
        parsed_repos =
          repos
          |> Enum.map(&parse_repo/1)
          |> Enum.filter(& &1.permissions.push)

        {:ok, parsed_repos}

      error ->
        error
    end
  end

  @impl true
  def get_repo(access_token, owner, repo_name) do
    case get("/repos/#{owner}/#{repo_name}", access_token) do
      {:ok, repo} -> {:ok, parse_repo(repo)}
      error -> error
    end
  end

  @impl true
  def list_branches(access_token, owner, repo_name, opts \\ []) do
    params = [
      per_page: Keyword.get(opts, :per_page, 100),
      page: Keyword.get(opts, :page, 1)
    ]

    case get("/repos/#{owner}/#{repo_name}/branches", access_token, params: params) do
      {:ok, branches} ->
        parsed =
          Enum.map(branches, fn b -> %{name: b["name"], protected: b["protected"] || false} end)

        {:ok, parsed}

      error ->
        error
    end
  end

  @impl true
  def clone_repo(_access_token, clone_url, local_path) do
    ssh_url = https_to_ssh(clone_url)

    case System.cmd("git", ["clone", ssh_url, local_path], stderr_to_stdout: true) do
      {_, 0} -> {:ok, local_path}
      {output, code} -> {:error, {:git_error, code, output}}
    end
  end

  defp https_to_ssh(url) do
    # Convert https://github.com/owner/repo.git to git@github.com:owner/repo.git
    url
    |> String.replace("https://github.com/", "git@github.com:")
    |> String.replace("https://www.github.com/", "git@github.com:")
  end

  # Pull request operations

  @impl true
  def create_pull_request(access_token, owner, repo_name, params) do
    body = %{
      title: params.title,
      body: params[:body],
      head: params.head,
      base: params.base
    }

    case post("/repos/#{owner}/#{repo_name}/pulls", access_token, body) do
      {:ok, pr} -> {:ok, parse_pull_request(pr)}
      error -> error
    end
  end

  @impl true
  def get_pull_request(access_token, owner, repo_name, pr_number) do
    case get("/repos/#{owner}/#{repo_name}/pulls/#{pr_number}", access_token) do
      {:ok, pr} -> {:ok, parse_pull_request(pr)}
      error -> error
    end
  end

  @impl true
  def list_pull_requests(access_token, owner, repo_name, opts \\ []) do
    params = [
      state: Keyword.get(opts, :state, "open"),
      per_page: Keyword.get(opts, :per_page, 30),
      page: Keyword.get(opts, :page, 1)
    ]

    case get("/repos/#{owner}/#{repo_name}/pulls", access_token, params: params) do
      {:ok, prs} -> {:ok, Enum.map(prs, &parse_pull_request/1)}
      error -> error
    end
  end

  @impl true
  def update_pull_request(access_token, owner, repo_name, pr_number, params) do
    body =
      %{}
      |> maybe_put(:title, params[:title])
      |> maybe_put(:body, params[:body])
      |> maybe_put(:state, params[:state])

    case patch("/repos/#{owner}/#{repo_name}/pulls/#{pr_number}", access_token, body) do
      {:ok, pr} -> {:ok, parse_pull_request(pr)}
      error -> error
    end
  end

  # Comment operations

  @impl true
  def create_pr_comment(access_token, owner, repo_name, pr_number, body) do
    # GitHub uses the issues API for PR comments
    case post("/repos/#{owner}/#{repo_name}/issues/#{pr_number}/comments", access_token, %{
           body: body
         }) do
      {:ok, comment} -> {:ok, parse_comment(comment)}
      error -> error
    end
  end

  @impl true
  def list_pr_comments(access_token, owner, repo_name, pr_number) do
    case get("/repos/#{owner}/#{repo_name}/issues/#{pr_number}/comments", access_token) do
      {:ok, comments} -> {:ok, Enum.map(comments, &parse_comment/1)}
      error -> error
    end
  end

  # User operations

  @impl true
  def get_user(access_token) do
    case get("/user", access_token) do
      {:ok, user} -> {:ok, parse_user(user)}
      error -> error
    end
  end

  # HTTP helper functions

  defp get(path, access_token, opts \\ []) do
    url = @github_api_url <> path
    params = Keyword.get(opts, :params, [])

    case Req.get(url, headers: auth_headers(access_token), params: params) do
      {:ok, response} -> handle_response(response)
      {:error, reason} -> {:error, reason}
    end
  end

  defp post(path, access_token, body) do
    url = @github_api_url <> path

    case Req.post(url, headers: auth_headers(access_token), json: body) do
      {:ok, response} -> handle_response(response, created: 201)
      {:error, reason} -> {:error, reason}
    end
  end

  defp patch(path, access_token, body) do
    url = @github_api_url <> path

    case Req.patch(url, headers: auth_headers(access_token), json: body) do
      {:ok, response} -> handle_response(response)
      {:error, reason} -> {:error, reason}
    end
  end

  defp handle_response(response, opts \\ []) do
    success_status = Keyword.get(opts, :created, 200)

    case response do
      %{status: ^success_status, body: body} -> {:ok, body}
      %{status: 200, body: body} -> {:ok, body}
      %{status: 201, body: body} -> {:ok, body}
      %{status: 401} -> {:error, :unauthorized}
      %{status: 404} -> {:error, :not_found}
      %{status: 422, body: body} -> {:error, {:validation_error, body}}
      %{status: status, body: body} -> {:error, {:api_error, status, body}}
    end
  end

  defp auth_headers(access_token) do
    [
      {"Authorization", "Bearer #{access_token}"},
      {"Accept", "application/vnd.github+json"},
      {"X-GitHub-Api-Version", "2022-11-28"}
    ]
  end

  # Parsing functions

  defp parse_repo(repo) do
    %{
      id: to_string(repo["id"]),
      name: repo["name"],
      full_name: repo["full_name"],
      description: repo["description"],
      private: repo["private"],
      html_url: repo["html_url"],
      clone_url: repo["clone_url"],
      ssh_url: repo["ssh_url"],
      default_branch: repo["default_branch"],
      owner: %{
        login: repo["owner"]["login"],
        avatar_url: repo["owner"]["avatar_url"]
      },
      permissions: %{
        admin: get_in(repo, ["permissions", "admin"]) || false,
        push: get_in(repo, ["permissions", "push"]) || false,
        pull: get_in(repo, ["permissions", "pull"]) || false
      },
      updated_at: repo["updated_at"],
      pushed_at: repo["pushed_at"]
    }
  end

  defp parse_user(user) do
    %{
      id: to_string(user["id"]),
      login: user["login"],
      name: user["name"],
      email: user["email"],
      avatar_url: user["avatar_url"]
    }
  end

  defp parse_pull_request(pr) do
    %{
      id: to_string(pr["id"]),
      number: pr["number"],
      title: pr["title"],
      body: pr["body"],
      state: pr["state"],
      html_url: pr["html_url"],
      head_branch: get_in(pr, ["head", "ref"]),
      base_branch: get_in(pr, ["base", "ref"]),
      head_sha: get_in(pr, ["head", "sha"]),
      created_at: pr["created_at"],
      updated_at: pr["updated_at"],
      merged_at: pr["merged_at"],
      user: %{
        login: get_in(pr, ["user", "login"]),
        avatar_url: get_in(pr, ["user", "avatar_url"])
      }
    }
  end

  defp parse_comment(comment) do
    %{
      id: to_string(comment["id"]),
      body: comment["body"],
      html_url: comment["html_url"],
      created_at: comment["created_at"],
      user: %{
        login: get_in(comment, ["user", "login"]),
        avatar_url: get_in(comment, ["user", "avatar_url"])
      }
    }
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
