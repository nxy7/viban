defmodule Viban.Kanban do
  @moduledoc """
  Domain for the Kanban board system.

  This domain manages all Kanban-related resources including boards, columns,
  tasks, hooks, and repositories. It provides the core functionality for
  task management with AI-powered automation capabilities.

  ## Resources

  ### Core Resources
  - `Viban.Kanban.Board` - Kanban boards owned by users
  - `Viban.Kanban.Column` - Columns within boards (TODO, In Progress, etc.)
  - `Viban.Kanban.Task` - Tasks with AI agent integration

  ### Automation Resources
  - `Viban.Kanban.Hook` - Reusable automation hooks (scripts or AI agents)
  - `Viban.Kanban.ColumnHook` - Association between columns and hooks

  ### Integration Resources
  - `Viban.Kanban.Repository` - Git repositories for task worktrees
  - `Viban.Kanban.Message` - Conversation messages between users and AI agents

  ## Extensions

  - `AshTypescript` - Frontend type generation
  - `AshTypescript.Rpc` - TypeScript RPC bindings
  - `AshAi` - MCP tool definitions for AI agents
  """

  use Ash.Domain,
    extensions: [AshTypescript.Domain, AshTypescript.Rpc, AshAi, AshSync],
    otp_app: :viban

  # ============================================================================
  # AshSync Configuration
  # ============================================================================

  sync do
    resource Viban.Kanban.Board do
      query(:sync_boards, :read)
    end

    resource Viban.Kanban.Column do
      query(:sync_columns, :read)
    end

    resource Viban.Kanban.Task do
      query(:sync_tasks, :read)
    end

    resource Viban.Kanban.Hook do
      query(:sync_hooks, :read)
    end

    resource Viban.Kanban.ColumnHook do
      query(:sync_column_hooks, :read)
    end

    resource Viban.Kanban.Repository do
      query(:sync_repositories, :read)
    end

    resource Viban.Kanban.Message do
      query(:sync_messages, :read)
    end

    resource Viban.Kanban.HookExecution do
      query(:sync_hook_executions, :read)
    end
  end

  # ============================================================================
  # Resources
  # ============================================================================

  resources do
    # Core Kanban resources
    resource Viban.Kanban.Board
    resource Viban.Kanban.Column
    resource Viban.Kanban.Task

    # Automation resources
    resource Viban.Kanban.Hook
    resource Viban.Kanban.ColumnHook

    # Integration resources
    resource Viban.Kanban.Repository
    resource Viban.Kanban.Message

    # Hook execution tracking
    resource Viban.Kanban.HookExecution
  end

  # ============================================================================
  # MCP Tool Definitions for AI Agents
  # ============================================================================

  tools do
    # Board tools
    tool :list_boards, Viban.Kanban.Board, :read do
      description "List all kanban boards accessible to the current user"
    end

    # Task management tools
    tool :list_tasks, Viban.Kanban.Task, :read do
      description "List tasks with optional filtering by column, status, or priority"
    end

    tool :create_task, Viban.Kanban.Task, :create do
      description "Create a new task in a specified column"
    end

    tool :update_task, Viban.Kanban.Task, :update do
      description "Update a task's title, description, or priority"
    end

    tool :move_task, Viban.Kanban.Task, :move do
      description "Move a task to a different column or reorder within the same column"
    end

    tool :delete_task, Viban.Kanban.Task, :destroy do
      description "Permanently delete a task and its associated data"
    end

    # Column tools
    tool :list_columns, Viban.Kanban.Column, :read do
      description "List all columns for a specific board, ordered by position"
    end

    # Hook tools
    tool :list_hooks, Viban.Kanban.Hook, :read do
      description "List automation hooks configured for a board"
    end

    tool :create_hook, Viban.Kanban.Hook, :create do
      description "Create a new automation hook with shell command or AI agent"
    end

    # Repository tools
    tool :list_repositories, Viban.Kanban.Repository, :read do
      description "List git repositories associated with boards"
    end
  end

  # ============================================================================
  # TypeScript RPC Configuration
  # ============================================================================

  typescript_rpc do
    resource Viban.Kanban.Board do
      rpc_action(:create_board, :create)
      rpc_action(:list_boards, :read)
      rpc_action(:get_board, :read, get?: true)
      rpc_action(:update_board, :update)
      rpc_action(:destroy_board, :destroy)
    end

    resource Viban.Kanban.Column do
      rpc_action(:create_column, :create)
      rpc_action(:list_columns, :read)
      rpc_action(:get_column, :read, get?: true)
      rpc_action(:update_column, :update)
      rpc_action(:destroy_column, :destroy)
      rpc_action(:update_column_settings, :update_settings)
      rpc_action(:delete_all_column_tasks, :delete_all_tasks)
    end

    resource Viban.Kanban.Task do
      rpc_action(:create_task, :create)
      rpc_action(:list_tasks, :read)
      rpc_action(:get_task, :read, get?: true)
      rpc_action(:update_task, :update)
      rpc_action(:destroy_task, :destroy)
      rpc_action(:move_task, :move)
      rpc_action(:refine_task, :refine)
      rpc_action(:refine_preview, :refine_preview)
      rpc_action(:generate_subtasks, :generate_subtasks)
      rpc_action(:list_subtasks, :subtasks)
      rpc_action(:create_subtask, :create_subtask)
      rpc_action(:create_task_pr, :create_pr)
      rpc_action(:clear_task_error, :clear_error)
    end

    resource Viban.Kanban.Hook do
      rpc_action(:create_hook, :create)
      rpc_action(:list_hooks, :read)
      rpc_action(:get_hook, :read, get?: true)
      rpc_action(:update_hook, :update)
      rpc_action(:destroy_hook, :destroy)
      rpc_action(:create_script_hook, :create_script_hook)
      rpc_action(:create_agent_hook, :create_agent_hook)
    end

    resource Viban.Kanban.ColumnHook do
      rpc_action(:create_column_hook, :create)
      rpc_action(:list_column_hooks, :read)
      rpc_action(:get_column_hook, :read, get?: true)
      rpc_action(:update_column_hook, :update)
      rpc_action(:destroy_column_hook, :destroy)
    end

    resource Viban.Kanban.Repository do
      rpc_action(:create_repository, :create)
      rpc_action(:list_repositories, :read)
      rpc_action(:get_repository, :read, get?: true)
      rpc_action(:update_repository, :update)
      rpc_action(:destroy_repository, :destroy)
      rpc_action(:list_branches, :list_branches)
    end

    resource Viban.Kanban.Message do
      rpc_action(:create_message, :create)
      rpc_action(:list_messages, :read)
      rpc_action(:get_message, :read, get?: true)
      rpc_action(:update_message, :update)
      rpc_action(:destroy_message, :destroy)
      rpc_action(:messages_for_task, :for_task)
    end

    resource Viban.Kanban.HookExecution do
      rpc_action(:list_hook_executions, :read)
      rpc_action(:get_hook_execution, :read, get?: true)
      rpc_action(:hook_executions_for_task, :history_for_task)
    end
  end
end
