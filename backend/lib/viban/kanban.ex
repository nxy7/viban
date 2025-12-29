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
    extensions: [AshTypescript.Domain, AshTypescript.Rpc, AshAi]

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
      rpc_action(:create, :create)
      rpc_action(:read, :read)
      rpc_action(:update, :update)
      rpc_action(:destroy, :destroy)
    end

    resource Viban.Kanban.Column do
      rpc_action(:create, :create)
      rpc_action(:read, :read)
      rpc_action(:update, :update)
      rpc_action(:destroy, :destroy)
    end

    resource Viban.Kanban.Task do
      rpc_action(:create, :create)
      rpc_action(:read, :read)
      rpc_action(:update, :update)
      rpc_action(:destroy, :destroy)
      rpc_action(:move, :move)
    end

    resource Viban.Kanban.Hook do
      rpc_action(:create, :create)
      rpc_action(:read, :read)
      rpc_action(:update, :update)
      rpc_action(:destroy, :destroy)
    end

    resource Viban.Kanban.ColumnHook do
      rpc_action(:create, :create)
      rpc_action(:read, :read)
      rpc_action(:update, :update)
      rpc_action(:destroy, :destroy)
    end

    resource Viban.Kanban.Repository do
      rpc_action(:create, :create)
      rpc_action(:read, :read)
      rpc_action(:update, :update)
      rpc_action(:destroy, :destroy)
    end

    resource Viban.Kanban.Message do
      rpc_action(:create, :create)
      rpc_action(:read, :read)
      rpc_action(:update, :update)
      rpc_action(:destroy, :destroy)
      rpc_action(:for_task, :for_task)
    end
  end
end
