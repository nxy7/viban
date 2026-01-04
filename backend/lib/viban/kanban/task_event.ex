defmodule Viban.Kanban.TaskEvent do
  @moduledoc """
  Union resource for all task events stored in the `task_events` table.

  This resource provides a unified view of all event types (messages, hook executions,
  executor sessions, executor outputs) for a task. It's read-only and used primarily
  for Electric sync - individual event types should be created/updated through their
  specific resources (Message, HookExecution, ExecutorSession, ExecutorMessage).

  ## Event Types

  - `message` - User/AI chat messages
  - `hook_execution` - Hook runs (Execute AI, Play Sound, Move Task, etc.)
  - `session` - AI executor sessions (start/end)
  - `executor_output` - AI tool calls, intermediate outputs

  ## Usage

  Query all events for a task in chronological order:

      TaskEvent.for_task(task_id)

  Filter by type in frontend using the `type` field.
  """

  use Ash.Resource,
    domain: Viban.Kanban,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshTypescript.Resource]

  typescript do
    type_name("TaskEvent")
  end

  postgres do
    table "task_events"
    repo Viban.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :type, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:message, :hook_execution, :session, :executor_output]
      description "Event type discriminator"
    end

    attribute :status, :atom do
      public? true

      constraints one_of: [
                    :pending,
                    :processing,
                    :running,
                    :completed,
                    :failed,
                    :cancelled,
                    :skipped,
                    :stopped
                  ]

      description "Event status"
    end

    attribute :role, :atom do
      public? true
      constraints one_of: [:user, :assistant, :system, :tool]
      description "Message role (for message/executor_output types)"
    end

    attribute :content, :string do
      public? true
      description "Message content (for message/executor_output types)"
    end

    attribute :hook_name, :string do
      public? true
      description "Human-readable hook name (for hook_execution type)"
    end

    attribute :hook_id, :string do
      public? true
      description "Hook ID that was executed (for hook_execution type)"
    end

    attribute :hook_settings, :map do
      public? true
      default %{}
      description "Hook-specific settings at time of execution"
    end

    attribute :skip_reason, :atom do
      public? true
      constraints one_of: [:error, :disabled, :column_change, :server_restart, :user_cancelled]
      description "Why the hook was cancelled/skipped"
    end

    attribute :error_message, :string do
      public? true
      description "Error details for failed events"
    end

    attribute :queued_at, :utc_datetime_usec do
      public? true
      description "When the hook was added to the queue"
    end

    attribute :started_at, :utc_datetime_usec do
      public? true
      description "When execution started"
    end

    attribute :completed_at, :utc_datetime_usec do
      public? true
      description "When execution finished"
    end

    attribute :triggering_column_id, :uuid do
      public? true
      description "Column that triggered hook execution"
    end

    attribute :executor_type, :atom do
      public? true

      constraints one_of: [
                    :claude_code,
                    :gemini_cli,
                    :codex,
                    :opencode,
                    :api_anthropic,
                    :api_openai
                  ]

      description "Executor type (for session type)"
    end

    attribute :prompt, :string do
      public? true
      description "Prompt given to executor (for session type)"
    end

    attribute :exit_code, :integer do
      public? true
      description "Exit code from executor process"
    end

    attribute :working_directory, :string do
      public? true
      description "Working directory for executor session"
    end

    attribute :session_id, :uuid do
      public? true
      description "Links executor_output to its session"
    end

    attribute :sequence, :integer do
      public? true
      description "Message sequence number within task (for message type)"
    end

    attribute :metadata, :map do
      public? true
      default %{}
      description "Additional event metadata"
    end

    timestamps()
  end

  relationships do
    belongs_to :task, Viban.Kanban.Task do
      allow_nil? false
      public? true
      description "The task this event belongs to"
    end

    belongs_to :column_hook, Viban.Kanban.ColumnHook do
      public? true
      description "Column hook configuration (for hook_execution type)"
    end
  end

  actions do
    defaults [:read]

    read :for_task do
      description "Get all events for a task, ordered chronologically"

      argument :task_id, :uuid do
        allow_nil? false
        description "The task's ID"
      end

      filter expr(task_id == ^arg(:task_id))
      prepare build(sort: [inserted_at: :asc])
    end
  end

  code_interface do
    define :read
    define :for_task, args: [:task_id]
    define :get, action: :read, get_by: [:id]
  end
end
