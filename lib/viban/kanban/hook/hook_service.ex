defmodule Viban.Kanban.Hook.HookService do
  @moduledoc """
  Service layer for hooks that merges system (virtual) hooks with database hooks.

  Provides a unified interface for:
  - Listing all available hooks (system + custom)
  - Getting hook details by ID
  - Executing hooks

  ## System vs Database Hooks

  - **System hooks** are defined in code via `Viban.Kanban.SystemHooks.Registry`
  - **Database hooks** are stored in the database and can be customized per board

  System hooks are identified by their string ID format (e.g., "system:execute-ai").

  ## Hook Map Structure

  Both system and database hooks are normalized to a common map structure with fields:
  - `id` - unique identifier
  - `name` - display name
  - `description` - optional description
  - `hook_kind` - `:script`, `:agent`, or `:system`
  - `command` - shell command (for script hooks)
  - `agent_prompt` - AI prompt (for agent hooks)
  - `is_system` - boolean indicating if this is a system hook
  """

  alias Viban.Kanban.Actors.HookRunner
  alias Viban.Kanban.Hook
  alias Viban.Kanban.SystemHooks.Registry

  require Logger

  @typedoc "Hook identifier (UUID for database hooks, prefixed string for system hooks)"
  @type hook_id :: String.t()

  @typedoc "Board identifier"
  @type board_id :: String.t()

  @typedoc "Task map with at least id and worktree_path"
  @type task :: %{required(:id) => String.t(), optional(:worktree_path) => String.t() | nil}

  @typedoc "Column map or nil"
  @type column :: map() | nil

  @typedoc "Normalized hook representation"
  @type hook_map :: %{
          id: String.t(),
          name: String.t(),
          description: String.t() | nil,
          hook_kind: :script | :agent | :system,
          command: String.t() | nil,
          agent_prompt: String.t() | nil,
          agent_executor: atom() | nil,
          agent_auto_approve: boolean() | nil,
          working_directory: :worktree | :project_root | String.t() | nil,
          timeout_ms: pos_integer() | nil,
          is_system: boolean()
        }

  @typedoc "Result of hook execution"
  @type hook_result :: {:ok, term()} | {:error, term()}

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  List all available hooks for a board (system + custom).

  Returns a list of normalized hook maps with system hooks first,
  followed by custom database hooks sorted by name.

  ## Examples

      iex> HookService.list_all_hooks("board-uuid")
      [
        %{id: "system:create-branch", name: "Create Branch", is_system: true, ...},
        %{id: "custom-uuid", name: "My Hook", is_system: false, ...}
      ]
  """
  @spec list_all_hooks(board_id()) :: [hook_map()]
  def list_all_hooks(board_id) do
    db_hooks = list_database_hooks(board_id)
    system_hooks = Registry.all()

    system_hooks ++ db_hooks
  end

  @doc """
  Get a hook by ID (handles both system and database hooks).

  Automatically routes to the appropriate source based on the hook ID format.

  ## Examples

      # System hook
      iex> HookService.get_hook("system:create-branch")
      {:ok, %{id: "system:create-branch", is_system: true, ...}}

      # Database hook
      iex> HookService.get_hook("550e8400-e29b-41d4-a716-446655440000")
      {:ok, %{id: "550e8400-...", is_system: false, ...}}

      # Not found
      iex> HookService.get_hook("unknown")
      {:error, %Ash.Error.Query.NotFound{...}}
  """
  @spec get_hook(hook_id()) :: {:ok, hook_map()} | {:error, term()}
  def get_hook(id) do
    if system_hook?(id) do
      Registry.get(id)
    else
      case Hook.get(id) do
        {:ok, hook} -> {:ok, db_hook_to_map(hook)}
        {:error, _} = error -> error
      end
    end
  end

  @doc """
  Execute a hook (handles both system and database hooks).

  Automatically routes execution to the appropriate handler based on the hook type.
  System hooks are executed via the Registry, database hooks via HookRunner.

  ## Options

  Options are passed through to the hook executor and may include:
  - `:timeout_ms` - execution timeout
  - `:working_directory` - override working directory

  ## Returns

  - `{:ok, result}` - hook executed successfully
  - `{:error, reason}` - hook execution failed
  """
  @spec execute_hook(hook_id(), task(), column(), keyword()) :: hook_result()
  def execute_hook(hook_id, task, column, opts \\ []) do
    if system_hook?(hook_id) do
      execute_system_hook(hook_id, task, column, opts)
    else
      execute_database_hook(hook_id, task, opts)
    end
  end

  @doc """
  Check if a hook ID is a system hook.

  System hooks have IDs prefixed with "system:" (e.g., "system:create-branch").
  """
  @spec system_hook?(hook_id()) :: boolean()
  def system_hook?(hook_id) do
    Registry.system_hook?(hook_id)
  end

  # ============================================================================
  # Private Functions - Database Hooks
  # ============================================================================

  @spec list_database_hooks(board_id()) :: [hook_map()]
  defp list_database_hooks(board_id) do
    import Ash.Query

    Hook
    |> filter(board_id: board_id)
    |> Ash.read!()
    |> Enum.map(&db_hook_to_map/1)
    |> Enum.sort_by(& &1.name)
  end

  @spec execute_database_hook(hook_id(), task(), keyword()) :: hook_result()
  defp execute_database_hook(hook_id, task, _opts) do
    case Hook.get(hook_id) do
      {:ok, hook} ->
        Logger.info("[HookService] Executing DB hook '#{hook.name}' for task #{task.id}")
        HookRunner.run_once(hook, task.worktree_path)

      {:error, _} = error ->
        Logger.error("[HookService] Hook #{hook_id} not found")
        error
    end
  end

  @spec db_hook_to_map(Hook.t()) :: hook_map()
  defp db_hook_to_map(hook) do
    %{
      id: hook.id,
      name: hook.name,
      description: nil,
      hook_kind: hook.hook_kind,
      command: hook.command,
      agent_prompt: hook.agent_prompt,
      agent_executor: hook.agent_executor,
      agent_auto_approve: hook.agent_auto_approve,
      working_directory: nil,
      timeout_ms: nil,
      is_system: false,
      default_execute_once: hook.default_execute_once || false,
      default_transparent: hook.default_transparent || false
    }
  end

  # ============================================================================
  # Private Functions - System Hooks
  # ============================================================================

  @spec execute_system_hook(hook_id(), task(), column(), keyword()) :: hook_result()
  defp execute_system_hook(hook_id, task, column, opts) do
    Logger.info("[HookService] Executing system hook #{hook_id} for task #{task.id}")
    Registry.execute(hook_id, task, column, opts)
  end
end
