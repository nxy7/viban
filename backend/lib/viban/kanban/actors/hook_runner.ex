defmodule Viban.Kanban.Actors.HookRunner do
  @moduledoc """
  Executes hooks (script or agent) when tasks enter columns.

  ## Hook Kinds

  - `:script` - Shell command execution
  - `:agent` - AI agent with prompt
  - `:system` - Built-in system hooks

  All hooks execute in the task's git worktree directory.

  ## Error Handling

  All execution functions return `{:ok, result}` or `{:error, reason}`.
  Errors include exit codes and missing working directories.
  """

  require Logger

  alias Viban.Executors.HookExecutor

  # Default shell for script execution
  @default_shell "/bin/bash"

  # Script file permissions (rwx for owner)
  @script_permissions 0o755

  # Shebang prefix for detecting existing shebangs
  @shebang_prefix "#!"

  @typedoc "Hook definition map"
  @type hook :: %{
          required(:name) => String.t(),
          optional(:hook_kind) => :script | :agent | :system,
          optional(:command) => String.t(),
          optional(:agent_prompt) => String.t(),
          optional(:agent_executor) => atom(),
          optional(:agent_auto_approve) => boolean()
        }

  @typedoc "Task definition map"
  @type task :: %{
          required(:id) => String.t(),
          optional(:worktree_path) => String.t() | nil,
          optional(:title) => String.t(),
          optional(:description) => String.t()
        }

  @typedoc "Result of hook execution"
  @type hook_result :: {:ok, String.t() | :skipped} | {:error, term()}

  @typedoc "Error with exit code and output"
  @type exit_error :: {:exit_code, non_neg_integer(), String.t()}

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Execute a hook based on its kind.

  Returns `{:ok, output}` or `{:error, reason}`.
  """
  @spec execute(hook(), task(), String.t() | nil, keyword()) :: hook_result()
  def execute(hook, task, column_name \\ nil, opts \\ []) do
    # Use Map.get to support both structs and maps
    hook_kind = Map.get(hook, :hook_kind)

    case hook_kind do
      :system -> execute_system_hook(hook, task, column_name, opts)
      :script -> run_once(hook, task.worktree_path)
      :agent -> execute_agent(hook, task, column_name, opts)
      _ -> run_once(hook, task.worktree_path)
    end
  end

  @doc """
  Execute a system hook via the Registry.
  """
  def execute_system_hook(hook, task, _column_name, opts) do
    alias Viban.Kanban.SystemHooks.Registry

    Logger.info("[HookRunner] Running system hook: #{hook.name}")

    # Get the column for the task
    column =
      case Viban.Kanban.Column.get(task.column_id) do
        {:ok, col} -> col
        _ -> nil
      end

    case Registry.execute(hook.id, task, column, opts) do
      :ok ->
        Logger.info("[HookRunner] System hook '#{hook.name}' completed")
        {:ok, "completed"}

      {:await_executor, task_id} ->
        # Hook started an async executor - return this so caller can handle appropriately
        Logger.info("[HookRunner] System hook '#{hook.name}' started async executor, awaiting completion")
        {:await_executor, task_id}

      {:error, reason} ->
        Logger.error("[HookRunner] System hook '#{hook.name}' failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Run a script hook.

  Blocks until the command completes. Always executes in the task's worktree.
  """
  @spec run_once(hook(), String.t() | nil) :: hook_result()
  def run_once(hook, worktree_path) do
    if valid_working_dir?(worktree_path) do
      execute_script(hook, worktree_path)
    else
      Logger.warning(
        "Skipping hook '#{hook.name}' - worktree not available: #{inspect(worktree_path)}"
      )

      {:ok, :skipped}
    end
  end

  @doc """
  Execute an agent hook - runs an AI agent with the specified prompt.

  Always executes in the task's worktree.
  """
  @spec execute_agent(hook(), task(), String.t() | nil, keyword()) :: hook_result()
  def execute_agent(hook, task, column_name, _opts) do
    full_prompt = HookExecutor.build_agent_prompt(hook.agent_prompt, task, column_name)

    Logger.info("[HookRunner] Running agent hook: #{hook.name}")

    case HookExecutor.run(
           task,
           full_prompt,
           hook.agent_executor || :claude_code,
           working_directory: task.worktree_path,
           auto_approve: hook.agent_auto_approve
         ) do
      {:ok, result} ->
        Logger.info("[HookRunner] Agent hook '#{hook.name}' completed")
        {:ok, result}

      {:error, reason} ->
        Logger.error("[HookRunner] Agent hook '#{hook.name}' failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # ============================================================================
  # Private Functions - Script Execution
  # ============================================================================

  defp execute_script(hook, working_dir) do
    Logger.info("Running hook '#{hook.name}' in #{working_dir}")

    script_path = write_temp_script(hook.command)

    try do
      run_script_in_port(script_path, working_dir, hook.name)
    after
      File.rm(script_path)
    end
  end

  defp run_script_in_port(script_path, working_dir, hook_name) do
    port =
      Port.open({:spawn_executable, script_path}, [
        :binary,
        :exit_status,
        :stderr_to_stdout,
        {:cd, working_dir}
      ])

    case collect_output(port, "") do
      {:ok, output} ->
        Logger.info("Hook '#{hook_name}' completed successfully")
        Logger.debug("Output: #{output}")
        {:ok, output}

      {:error, {:exit_status, code, output}} ->
        Logger.error("Hook '#{hook_name}' failed with exit code #{code}: #{output}")
        {:error, {:exit_code, code, output}}

      {:error, reason} ->
        Logger.error("Hook '#{hook_name}' failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @spec write_temp_script(String.t()) :: String.t()
  defp write_temp_script(command) do
    path = Path.join(System.tmp_dir!(), "viban_hook_#{:erlang.unique_integer([:positive])}")

    script_content =
      if String.starts_with?(command, @shebang_prefix) do
        command
      else
        "#{@shebang_prefix}#{@default_shell}\nset -e\n#{command}"
      end

    File.write!(path, script_content)
    File.chmod!(path, @script_permissions)
    path
  end

  @spec collect_output(port(), String.t()) :: {:ok, String.t()} | {:error, term()}
  defp collect_output(port, acc) do
    receive do
      {^port, {:data, data}} ->
        collect_output(port, acc <> data)

      {^port, {:exit_status, 0}} ->
        {:ok, acc}

      {^port, {:exit_status, status}} ->
        {:error, {:exit_status, status, acc}}
    end
  end

  # ============================================================================
  # Private Functions - Working Directory
  # ============================================================================

  @spec valid_working_dir?(String.t() | nil) :: boolean()
  defp valid_working_dir?(nil), do: false
  defp valid_working_dir?(path), do: File.dir?(path)
end
