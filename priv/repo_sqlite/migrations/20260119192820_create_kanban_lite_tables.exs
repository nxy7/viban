defmodule Viban.RepoSqlite.Migrations.CreateKanbanLiteTables do
  @moduledoc """
  Creates all tables for the KanbanLite SQLite domain.

  This migration creates all the tables needed for the SQLite-backed
  Kanban system that uses Phoenix LiveView instead of SolidJS.
  """

  use Ecto.Migration

  def change do
    # =========================================================================
    # Boards
    # =========================================================================

    create table(:boards, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :name, :string, null: false
      add :description, :string
      add :user_id, :uuid, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:boards, [:user_id, :name])

    # =========================================================================
    # Columns
    # =========================================================================

    create table(:columns, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :name, :string, null: false
      add :position, :integer, null: false, default: 0
      add :color, :string, default: "#6366f1"
      add :settings, :map, default: %{}
      add :board_id, references(:boards, type: :uuid, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:columns, [:board_id, :name])
    create unique_index(:columns, [:board_id, :position])
    create index(:columns, [:board_id])

    # =========================================================================
    # Hooks
    # =========================================================================

    create table(:hooks, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :name, :string, null: false
      add :hook_kind, :string, null: false, default: "script"
      add :command, :string
      add :agent_prompt, :string
      add :agent_executor, :string, default: "claude_code"
      add :agent_auto_approve, :boolean, default: false
      add :default_execute_once, :boolean, default: false
      add :default_transparent, :boolean, default: false
      add :board_id, references(:boards, type: :uuid, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:hooks, [:board_id, :name])
    create index(:hooks, [:board_id])

    # =========================================================================
    # Column Hooks
    # =========================================================================

    create table(:column_hooks, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :hook_id, :string, null: false
      add :hook_type, :string, null: false, default: "on_entry"
      add :position, :integer, default: 0
      add :execute_once, :boolean, default: false
      add :hook_settings, :map, default: %{}
      add :transparent, :boolean, default: false
      add :removable, :boolean, default: true
      add :column_id, references(:columns, type: :uuid, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:column_hooks, [:column_id, :hook_id])
    create index(:column_hooks, [:column_id])

    # =========================================================================
    # Repositories
    # =========================================================================

    create table(:repositories, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :provider, :string, null: false, default: "local"
      add :provider_repo_id, :string
      add :name, :string, null: false
      add :full_name, :string
      add :clone_url, :string
      add :html_url, :string
      add :default_branch, :string, default: "main"
      add :local_path, :string
      add :clone_status, :string, default: "pending"
      add :clone_error, :string
      add :board_id, references(:boards, type: :uuid, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:repositories, [:board_id])

    # =========================================================================
    # Task Templates
    # =========================================================================

    create table(:task_templates, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :name, :string, null: false
      add :description_template, :string
      add :position, :integer, null: false, default: 0
      add :board_id, references(:boards, type: :uuid, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:task_templates, [:board_id])

    # =========================================================================
    # Periodical Tasks
    # =========================================================================

    create table(:periodical_tasks, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :title, :string, null: false
      add :description, :string
      add :schedule, :string, null: false
      add :executor, :string, default: "claude_code"
      add :execution_count, :integer, null: false, default: 0
      add :last_executed_at, :utc_datetime_usec
      add :next_execution_at, :utc_datetime_usec
      add :enabled, :boolean, null: false, default: true
      add :last_created_task_id, :uuid
      add :board_id, references(:boards, type: :uuid, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:periodical_tasks, [:board_id])

    # =========================================================================
    # Tasks
    # =========================================================================

    create table(:tasks, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :title, :string, null: false
      add :description, :string
      add :position, :string, null: false, default: "a0"
      add :priority, :string, default: "medium"
      add :description_images, :map, default: []

      # Git worktree
      add :worktree_path, :string
      add :worktree_branch, :string
      add :custom_branch_name, :string

      # Agent status
      add :agent_status, :string, default: "idle"
      add :agent_status_message, :string
      add :in_progress, :boolean, default: false
      add :error_message, :string

      # Queue management
      add :queued_at, :utc_datetime
      add :queue_priority, :integer, default: 0

      # Pull request
      add :pr_url, :string
      add :pr_number, :integer
      add :pr_status, :string

      # Parent-subtask
      add :is_parent, :boolean, default: false
      add :subtask_position, :integer, default: 0
      add :subtask_generation_status, :string

      # Hook tracking
      add :executed_hooks, :map, default: []
      add :message_queue, :map, default: []

      # Periodical task
      add :auto_start, :boolean, null: false, default: false

      # Relationships
      add :column_id, references(:columns, type: :uuid, on_delete: :delete_all), null: false
      add :parent_task_id, references(:tasks, type: :uuid, on_delete: :delete_all)
      add :periodical_task_id, references(:periodical_tasks, type: :uuid, on_delete: :nilify_all)

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:tasks, [:worktree_path], where: "worktree_path IS NOT NULL")
    create index(:tasks, [:column_id])
    create index(:tasks, [:parent_task_id])
    create index(:tasks, [:periodical_task_id])

    # =========================================================================
    # Task Events (unified table for messages, hook executions, sessions)
    # =========================================================================

    create table(:task_events, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :type, :string, null: false

      # Common fields
      add :task_id, references(:tasks, type: :uuid, on_delete: :delete_all), null: false

      # Message fields
      add :role, :string
      add :content, :string
      add :status, :string
      add :metadata, :map, default: %{}
      add :sequence, :integer

      # Hook execution fields
      add :hook_name, :string
      add :hook_id, :string
      add :skip_reason, :string
      add :error_message, :string
      add :hook_settings, :map
      add :queued_at, :utc_datetime_usec
      add :started_at, :utc_datetime_usec
      add :completed_at, :utc_datetime_usec
      add :triggering_column_id, :uuid
      add :column_hook_id, references(:column_hooks, type: :uuid, on_delete: :nilify_all)

      # Executor session fields
      add :executor_type, :string
      add :prompt, :string
      add :working_directory, :string
      add :exit_code, :integer
      add :session_id, :uuid

      timestamps(type: :utc_datetime_usec)
    end

    create index(:task_events, [:task_id])
    create index(:task_events, [:type])
    create index(:task_events, [:task_id, :type])
    create index(:task_events, [:session_id], where: "session_id IS NOT NULL")
  end
end
