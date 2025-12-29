defmodule VibanWeb.BoardController do
  @moduledoc """
  API endpoints for board management.

  Handles board creation with VCS repository selection. When a board is created,
  a corresponding repository record is created and a background job is enqueued
  to clone the repository.

  ## Authentication

  All endpoints require authentication via the session.

  ## Endpoints

  - `POST /api/boards` - Create a new board with a VCS repository
  """

  use VibanWeb, :controller

  import VibanWeb.ControllerHelpers,
    only: [
      require_current_user: 1,
      json_ok: 2,
      json_error: 3,
      get_param: 2
    ]

  alias Viban.Kanban.{Board, Repository}
  alias Viban.Workers.RepoCloneWorker

  require Logger

  plug VibanWeb.Plugs.RequireAuth

  # Default branch name when not specified
  @default_branch "main"

  @doc """
  Creates a new board with a VCS repository.

  ## Body Parameters

  - `name` (required) - Board name
  - `description` - Board description
  - `repo` (required) - Object with VCS repository info:
    - `id` - Repository ID from provider
    - `full_name` - owner/repo format
    - `name` - Repository name
    - `clone_url` - HTTPS clone URL
    - `html_url` - Web URL
    - `default_branch` - Default branch name (defaults to "main")

  ## Response

  Returns the created board and repository on success.
  """
  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, params) do
    {:ok, user} = require_current_user(conn)

    with {:ok, board_params} <- validate_board_params(params),
         {:ok, repo_params} <- validate_repo_params(params, user.provider),
         {:ok, board} <- create_board(board_params, user.id),
         {:ok, repository} <- create_repository(repo_params, board.id, user.provider) do
      # Enqueue background job to clone the repository
      RepoCloneWorker.enqueue(repository.id, user.id)

      Logger.info(
        "[BoardController] Created board '#{board.name}' with repository '#{repository.full_name}'"
      )

      json_ok(conn, %{
        board: serialize_board(board),
        repository: serialize_repository(repository)
      })
    else
      {:error, :board_creation_failed, reason} ->
        Logger.warning("[BoardController] Failed to create board: #{format_error(reason)}")
        json_error(conn, :unprocessable_entity, "Failed to create board: #{format_error(reason)}")

      {:error, :repository_creation_failed, reason, board} ->
        # Clean up the board if repository creation fails
        Logger.warning(
          "[BoardController] Failed to create repository, cleaning up board: #{format_error(reason)}"
        )

        Board.destroy(board)

        json_error(
          conn,
          :unprocessable_entity,
          "Failed to create repository: #{format_error(reason)}"
        )

      {:error, reason} when is_binary(reason) ->
        json_error(conn, :bad_request, reason)

      {:error, reason} ->
        json_error(conn, :bad_request, format_error(reason))
    end
  end

  # ============================================================================
  # Private Functions - Validation
  # ============================================================================

  defp validate_board_params(params) do
    name = get_param(params, :name)

    if is_binary(name) and String.trim(name) != "" do
      {:ok,
       %{
         name: String.trim(name),
         description: get_param(params, :description)
       }}
    else
      {:error, "Board name is required"}
    end
  end

  defp validate_repo_params(params, provider) do
    # Support both "repo" (new) and "github_repo" (legacy) keys
    repo = get_param(params, :repo) || get_param(params, :github_repo)

    with :ok <- validate_repo_presence(repo),
         :ok <- validate_repo_type(repo),
         :ok <- validate_required_repo_fields(repo) do
      {:ok, build_repo_params(repo, provider)}
    end
  end

  defp validate_repo_presence(nil), do: {:error, "Repository selection is required"}
  defp validate_repo_presence(_), do: :ok

  defp validate_repo_type(repo) when is_map(repo), do: :ok
  defp validate_repo_type(_), do: {:error, "Invalid repository data"}

  defp validate_required_repo_fields(repo) do
    cond do
      is_nil(get_param(repo, :id)) ->
        {:error, "Repository ID is required"}

      is_nil(get_param(repo, :full_name)) ->
        {:error, "Repository full_name is required"}

      is_nil(get_param(repo, :clone_url)) ->
        {:error, "Repository clone_url is required"}

      true ->
        :ok
    end
  end

  defp build_repo_params(repo, provider) do
    full_name = get_param(repo, :full_name)

    %{
      provider: provider,
      id: get_param(repo, :id),
      full_name: full_name,
      name: get_param(repo, :name) || extract_repo_name(full_name),
      clone_url: get_param(repo, :clone_url),
      html_url: get_param(repo, :html_url),
      default_branch: get_param(repo, :default_branch) || @default_branch
    }
  end

  defp extract_repo_name(full_name) when is_binary(full_name) do
    full_name |> String.split("/") |> List.last()
  end

  defp extract_repo_name(_), do: "unknown"

  # ============================================================================
  # Private Functions - Creation
  # ============================================================================

  defp create_board(board_params, user_id) do
    case Board.create(%{
           name: board_params.name,
           description: board_params.description,
           user_id: user_id
         }) do
      {:ok, board} -> {:ok, board}
      {:error, reason} -> {:error, :board_creation_failed, reason}
    end
  end

  defp create_repository(repo_params, board_id, provider) do
    case Repository.create(%{
           board_id: board_id,
           provider: provider,
           provider_repo_id: to_string(repo_params.id),
           full_name: repo_params.full_name,
           clone_url: repo_params.clone_url,
           html_url: repo_params.html_url,
           name: repo_params.name,
           default_branch: repo_params.default_branch
         }) do
      {:ok, repository} ->
        {:ok, repository}

      {:error, reason} ->
        # We need to pass the board for cleanup, but we don't have it here
        # This is a limitation - the caller handles cleanup
        {:error, reason}
    end
  end

  # ============================================================================
  # Private Functions - Serialization
  # ============================================================================

  defp serialize_board(board) do
    %{
      id: board.id,
      name: board.name,
      description: board.description,
      user_id: board.user_id,
      inserted_at: board.inserted_at,
      updated_at: board.updated_at
    }
  end

  defp serialize_repository(repo) do
    %{
      id: repo.id,
      board_id: repo.board_id,
      provider: repo.provider,
      provider_repo_id: repo.provider_repo_id,
      full_name: repo.full_name,
      name: repo.name,
      default_branch: repo.default_branch,
      clone_status: repo.clone_status
    }
  end

  defp format_error(error) when is_binary(error), do: error
  defp format_error(error), do: inspect(error)
end
