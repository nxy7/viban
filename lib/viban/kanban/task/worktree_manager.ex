defmodule Viban.Kanban.Task.WorktreeManager do
  @moduledoc """
  Manages git worktrees for tasks.

  Worktrees provide isolated development environments for each task,
  allowing parallel work on multiple tasks without branch switching.
  Each worktree gets its own directory with a dedicated branch.

  ## Features

  - Auto-clones repositories from GitHub when needed (no local repo required)
  - Uses remote tracking branch (origin/<default_branch>) as base
  - Automatic cleanup of expired worktrees
  - Custom branch name support

  ## Directory Structure

  Managed repositories are cloned to:

      ~/.local/share/viban/repos/
        <board_id>/
          ... (bare git repository)

  Worktrees are organized as:

      ~/.local/share/viban/worktrees/
        <board_id>/
          <task_id or branch_name>/
            ... (git worktree files)

  ## Configuration

  Configure via application environment:

      config :viban,
        worktree_base_path: "~/.local/share/viban/worktrees",
        repos_base_path: "~/.local/share/viban/repos",
        worktree_ttl_days: 7

  ## Usage

      # Create a worktree for a task
      {:ok, path, branch} = WorktreeManager.create_worktree(board_id, task_id)

      # With custom branch name
      {:ok, path, branch} = WorktreeManager.create_worktree(board_id, task_id, "viban/my-feature")

      # Remove a worktree
      :ok = WorktreeManager.remove_worktree(task_id, path, branch)

      # Cleanup old worktrees
      :ok = WorktreeManager.cleanup_expired_worktrees()
  """

  alias Viban.Kanban.Column
  alias Viban.Kanban.Message
  alias Viban.Kanban.Repository
  alias Viban.Kanban.Task

  require Logger

  @log_prefix "[Task.WorktreeManager]"

  @default_worktree_base_path "~/.local/share/viban/worktrees"
  @default_repos_base_path "~/.local/share/viban/repos"
  @default_ttl_days 7

  @terminal_columns ["done", "cancelled"]

  @type worktree_result :: {:ok, String.t(), String.t()} | {:error, term()}

  @type worktree_error ::
          :no_repository
          | :no_clone_url
          | {:clone_failed, integer(), String.t()}
          | {:git_error, integer(), String.t()}

  defp worktree_base_path do
    :viban
    |> Application.get_env(:worktree_base_path, @default_worktree_base_path)
    |> Path.expand()
  end

  defp repos_base_path do
    :viban
    |> Application.get_env(:repos_base_path, @default_repos_base_path)
    |> Path.expand()
  end

  defp worktree_ttl_days do
    Application.get_env(:viban, :worktree_ttl_days, @default_ttl_days)
  end

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Creates a worktree for a task.

  Creates a new git worktree with a dedicated branch for the task,
  based on the remote tracking branch (origin/<default_branch>).
  If the worktree already exists, returns its path without recreating.

  The repository is automatically cloned from GitHub if not already present.

  ## Parameters

  - `board_id` - The board UUID
  - `task_id` - The task UUID
  - `custom_branch_name` - Optional custom branch name (default: `viban/<task_id>`)

  ## Returns

  - `{:ok, worktree_path, branch_name}` - On success
  - `{:error, :no_repository}` - No repository configured for the board
  - `{:error, :no_clone_url}` - Repository has no clone_url configured
  - `{:error, {:clone_failed, code, output}}` - Git clone failed
  - `{:error, {:git_error, code, output}}` - Git command failed
  """
  @spec create_worktree(Ecto.UUID.t(), Ecto.UUID.t(), String.t() | nil) :: worktree_result()
  def create_worktree(board_id, task_id, custom_branch_name \\ nil) do
    with {:ok, repo} <- find_board_repository(board_id),
         {:ok, local_repo_path} <- ensure_local_clone(repo),
         {worktree_path, branch_name} <-
           build_worktree_paths(board_id, task_id, custom_branch_name),
         :ok <- ensure_parent_directory(worktree_path) do
      create_or_return_existing_worktree(repo, local_repo_path, worktree_path, branch_name)
    end
  end

  @doc """
  Removes a worktree for a task.

  Removes the git worktree and its associated branch. Falls back to
  direct directory removal if git worktree remove fails.

  ## Parameters

  - `task_id` - The task UUID (for logging)
  - `worktree_path` - Path to the worktree directory
  - `worktree_branch` - Name of the worktree branch
  - `opts` - Keyword list of options

  ## Options

  - `:add_activity` - If true, adds a system message to the task's history (default: false)

  ## Returns

  Always returns `:ok` (removal is best-effort).
  """
  @spec remove_worktree(Ecto.UUID.t(), String.t() | nil, String.t() | nil, keyword()) :: :ok
  def remove_worktree(task_id, worktree_path, worktree_branch, opts \\ []) do
    add_activity = Keyword.get(opts, :add_activity, false)

    cond do
      is_nil(worktree_path) ->
        Logger.debug("#{@log_prefix} Worktree path is nil for task #{task_id}")
        :ok

      not File.exists?(worktree_path) ->
        Logger.debug("#{@log_prefix} Worktree does not exist for task #{task_id}")
        :ok

      true ->
        Logger.info("#{@log_prefix} Removing worktree for task #{task_id} at #{worktree_path}")
        result = do_remove_worktree(worktree_path, worktree_branch)

        if add_activity and result == :ok do
          add_cleanup_activity(task_id)
        end

        result
    end
  end

  @doc """
  Cleans up worktrees for tasks in terminal columns older than TTL.

  This is typically called by a scheduled job to reclaim disk space from
  completed or cancelled tasks. Only removes worktrees for tasks that:

  1. Have a worktree path set
  2. Are in a terminal column (Done or Cancelled)
  3. Were last updated more than `worktree_ttl_days` ago
  """
  @spec cleanup_expired_worktrees() :: :ok
  def cleanup_expired_worktrees do
    cutoff = DateTime.add(DateTime.utc_now(), -worktree_ttl_days(), :day)
    Logger.info("#{@log_prefix} Cleaning up worktrees for tasks completed before #{cutoff}")

    case Task.read() do
      {:ok, tasks} ->
        tasks
        |> Enum.filter(&expired_worktree?(&1, cutoff))
        |> Enum.each(&cleanup_task_worktree/1)

      {:error, reason} ->
        Logger.error("#{@log_prefix} Failed to read tasks for cleanup: #{inspect(reason)}")
    end

    :ok
  end

  @doc """
  Checks if a worktree exists for the given path.

  ## Returns

  `true` if the path exists and is a directory, `false` otherwise.
  """
  @spec worktree_exists?(String.t() | nil) :: boolean()
  def worktree_exists?(nil), do: false
  def worktree_exists?(path), do: File.exists?(path)

  # ---------------------------------------------------------------------------
  # Private Functions - Repository Handling
  # ---------------------------------------------------------------------------

  defp find_board_repository(board_id) do
    case Repository.read() do
      {:ok, repos} ->
        case Enum.find(repos, &(&1.board_id == board_id)) do
          nil ->
            Logger.warning("#{@log_prefix} No repository configured for board #{board_id}")
            {:error, :no_repository}

          repo ->
            {:ok, repo}
        end

      _ ->
        {:error, :no_repository}
    end
  end

  defp ensure_local_clone(%{clone_url: nil, board_id: board_id}) do
    Logger.warning("#{@log_prefix} No clone_url configured for board #{board_id}")
    {:error, :no_clone_url}
  end

  defp ensure_local_clone(%{clone_url: clone_url, board_id: board_id} = repo) do
    local_repo_path = managed_repo_path(board_id)
    git_dir = Path.join(local_repo_path, ".git")

    cond do
      File.dir?(git_dir) ->
        Logger.debug("#{@log_prefix} Using existing managed clone at #{local_repo_path}")
        {:ok, local_repo_path}

      File.exists?(local_repo_path) ->
        Logger.warning("#{@log_prefix} Removing incomplete clone at #{local_repo_path}")
        File.rm_rf!(local_repo_path)
        clone_repository(clone_url, local_repo_path, repo)

      true ->
        clone_repository(clone_url, local_repo_path, repo)
    end
  end

  defp managed_repo_path(board_id) do
    Path.join(repos_base_path(), to_string(board_id))
  end

  defp clone_repository(clone_url, local_repo_path, repo) do
    File.mkdir_p!(Path.dirname(local_repo_path))

    Logger.info("#{@log_prefix} Cloning #{clone_url} to #{local_repo_path}")

    args = ["clone", clone_url, local_repo_path]

    case System.cmd("git", args, stderr_to_stdout: true) do
      {_, 0} ->
        Logger.info("#{@log_prefix} Successfully cloned repository to #{local_repo_path}")
        {:ok, local_repo_path}

      {output, code} ->
        Logger.error("""
        #{@log_prefix} Failed to clone repository (exit code #{code})
          Clone URL: #{clone_url}
          Board ID: #{repo.board_id}
          Target path: #{local_repo_path}
          Git output: #{String.trim(output)}
        """)

        {:error, {:clone_failed, code, output}}
    end
  end

  # ---------------------------------------------------------------------------
  # Private Functions - Path Building
  # ---------------------------------------------------------------------------

  defp build_worktree_paths(board_id, task_id, _custom_branch_name) do
    # Always use task_id for both folder name and branch to ensure uniqueness
    folder_name = to_string(task_id)
    worktree_path = Path.join([worktree_base_path(), to_string(board_id), folder_name])
    # Always use task_id in branch name to avoid collisions with other tasks
    branch_name = "viban/#{task_id}"

    {worktree_path, branch_name}
  end

  defp ensure_parent_directory(worktree_path) do
    File.mkdir_p!(Path.dirname(worktree_path))
    :ok
  end

  # ---------------------------------------------------------------------------
  # Private Functions - Worktree Creation
  # ---------------------------------------------------------------------------

  defp create_or_return_existing_worktree(repo, local_repo_path, worktree_path, branch_name) do
    if File.exists?(worktree_path) do
      Logger.info("#{@log_prefix} Worktree already exists at #{worktree_path}")
      {:ok, worktree_path, branch_name}
    else
      create_git_worktree(repo, local_repo_path, worktree_path, branch_name)
    end
  end

  defp create_git_worktree(repo, local_repo_path, worktree_path, branch_name) do
    default_branch = repo.default_branch || "main"
    remote_ref = "origin/#{default_branch}"

    with :ok <- fetch_remote(local_repo_path),
         :ok <- verify_remote_ref(local_repo_path, remote_ref) do
      do_create_worktree(local_repo_path, worktree_path, branch_name, remote_ref, repo)
    end
  end

  defp fetch_remote(local_path) do
    Logger.debug("#{@log_prefix} Fetching from origin in #{local_path}")

    case System.cmd("git", ["-C", local_path, "fetch", "origin"], stderr_to_stdout: true) do
      {_, 0} ->
        :ok

      {output, code} ->
        Logger.warning("#{@log_prefix} git fetch failed (code #{code}): #{output}")
        :ok
    end
  end

  defp verify_remote_ref(local_path, remote_ref) do
    case System.cmd("git", ["-C", local_path, "rev-parse", "--verify", remote_ref], stderr_to_stdout: true) do
      {_, 0} ->
        :ok

      {output, code} ->
        Logger.error("#{@log_prefix} Remote ref #{remote_ref} not found: #{output}")
        {:error, {:git_error, code, "Remote ref #{remote_ref} not found"}}
    end
  end

  defp do_create_worktree(local_path, worktree_path, branch_name, remote_ref, repo) do
    args = [
      "-C",
      local_path,
      "worktree",
      "add",
      "-b",
      branch_name,
      worktree_path,
      remote_ref
    ]

    case System.cmd("git", args, stderr_to_stdout: true) do
      {_, 0} ->
        Logger.info("#{@log_prefix} Created worktree at #{worktree_path} from #{remote_ref}")
        {:ok, worktree_path, branch_name}

      {output, code} ->
        Logger.error("""
        #{@log_prefix} Failed to create worktree (exit code #{code})
          Local path: #{local_path}
          Board ID: #{repo.board_id}
          Default branch: #{repo.default_branch}
          Remote ref: #{remote_ref}
          Target branch: #{branch_name}
          Worktree path: #{worktree_path}
          Git output: #{String.trim(output)}
        """)

        {:error, {:git_error, code, output}}
    end
  end

  # ---------------------------------------------------------------------------
  # Private Functions - Worktree Removal
  # ---------------------------------------------------------------------------

  defp do_remove_worktree(worktree_path, worktree_branch) do
    case find_repo_for_worktree(worktree_path) do
      {:ok, repo_path} ->
        remove_git_worktree(repo_path, worktree_path, worktree_branch)

      :error ->
        Logger.warning("#{@log_prefix} Could not find repo for worktree, removing directory directly")

        File.rm_rf!(worktree_path)
        :ok
    end
  end

  defp remove_git_worktree(repo_path, worktree_path, worktree_branch) do
    case System.cmd("git", ["-C", repo_path, "worktree", "remove", worktree_path, "--force"], stderr_to_stdout: true) do
      {_, 0} ->
        Logger.info("#{@log_prefix} Removed git worktree at #{worktree_path}")
        maybe_delete_branch(repo_path, worktree_branch)
        :ok

      {output, code} ->
        Logger.warning("#{@log_prefix} Git worktree remove failed (code #{code}): #{output}, falling back to rm -rf")

        File.rm_rf!(worktree_path)
        :ok
    end
  end

  defp maybe_delete_branch(_repo_path, nil), do: :ok

  defp maybe_delete_branch(repo_path, branch) do
    System.cmd("git", ["-C", repo_path, "branch", "-D", branch], stderr_to_stdout: true)
    :ok
  end

  defp find_repo_for_worktree(worktree_path) do
    parts = Path.split(worktree_path)

    case Enum.take(parts, -2) do
      [board_id_str, _task_id] ->
        {:ok, managed_repo_path(board_id_str)}

      _ ->
        :error
    end
  end

  # ---------------------------------------------------------------------------
  # Private Functions - Cleanup
  # ---------------------------------------------------------------------------

  defp expired_worktree?(task, cutoff) do
    task.worktree_path != nil and
      terminal_column?(task.column_id) and
      DateTime.before?(task.updated_at, cutoff)
  end

  defp cleanup_task_worktree(task) do
    Logger.info("#{@log_prefix} Cleaning up expired worktree for task #{task.id}")
    remove_worktree(task.id, task.worktree_path, task.worktree_branch, add_activity: true)
    Task.clear_worktree(task)
  end

  defp terminal_column?(column_id) do
    case Column.read() do
      {:ok, columns} ->
        case Enum.find(columns, &(&1.id == column_id)) do
          %{name: name} ->
            String.downcase(name) in @terminal_columns

          _ ->
            false
        end

      _ ->
        false
    end
  end

  defp add_cleanup_activity(task_id) do
    Message.create(%{
      task_id: task_id,
      role: :system,
      content: "Worktree was automatically cleaned up due to inactivity.",
      status: :completed
    })
  end
end
