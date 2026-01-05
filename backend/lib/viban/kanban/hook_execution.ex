defmodule Viban.Kanban.HookExecution do
  @moduledoc """
  Tracks individual hook executions for tasks.

  Replaces the embedded hook_queue and hook_history arrays with a proper
  database table. Each row represents one execution of a hook for a task.

  ## Status Lifecycle

  - `:pending` - Hook is queued, waiting for execution
  - `:running` - Hook is currently executing
  - `:completed` - Hook finished successfully
  - `:failed` - Hook finished with an error
  - `:cancelled` - Hook was cancelled (e.g., task moved to different column)
  - `:skipped` - Hook was skipped (e.g., disabled, already executed, server restart)

  ## Skip Reasons

  When status is `:cancelled` or `:skipped`, skip_reason indicates why:
  - `:error` - Skipped due to a previous hook error
  - `:disabled` - Hook was disabled in settings
  - `:column_change` - Task moved to a different column
  - `:server_restart` - Server restarted while hook was pending/running
  - `:user_cancelled` - User manually cancelled the hook
  """

  use Ash.Resource,
    domain: Viban.Kanban,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshTypescript.Resource]

  typescript do
    type_name("HookExecution")
  end

  postgres do
    table "task_events"
    repo Viban.Repo

    base_filter_sql "type = 'hook_execution'"
  end

  attributes do
    uuid_primary_key :id

    attribute :type, :atom do
      allow_nil? false
      default :hook_execution
      writable? false
      public? true
      constraints one_of: [:hook_execution]
      description "Event type discriminator (always 'hook_execution' for this resource)"
    end

    attribute :hook_name, :string do
      allow_nil? false
      public? true
      description "Human-readable name of the hook"
    end

    attribute :hook_id, :string do
      allow_nil? false
      public? true
      description "The column_hook ID or system hook ID that was executed"
    end

    attribute :status, :atom do
      allow_nil? false
      default :pending
      public? true
      constraints one_of: [:pending, :running, :completed, :failed, :cancelled, :skipped]
      description "Current execution status"
    end

    attribute :skip_reason, :atom do
      public? true
      constraints one_of: [:error, :disabled, :column_change, :server_restart, :user_cancelled]
      description "Why the hook was cancelled/skipped"
    end

    attribute :error_message, :string do
      public? true
      description "Error details if status is :failed"
    end

    attribute :hook_settings, :map do
      default %{}
      public? true
      description "Hook-specific settings at time of execution"
    end

    attribute :queued_at, :utc_datetime_usec do
      allow_nil? false
      public? true
      description "When the hook was added to the queue"
    end

    attribute :started_at, :utc_datetime_usec do
      public? true
      description "When the hook started executing"
    end

    attribute :completed_at, :utc_datetime_usec do
      public? true
      description "When the hook finished (success or failure)"
    end

    attribute :triggering_column_id, :uuid do
      public? true
      description "The column that triggered this hook execution"
    end

    timestamps()
  end

  relationships do
    belongs_to :task, Viban.Kanban.Task do
      allow_nil? false
      public? true
      attribute_writable? true
      description "The task this execution belongs to"
    end

    belongs_to :column_hook, Viban.Kanban.ColumnHook do
      public? true
      attribute_writable? true
      description "The column hook configuration (nil for system hooks)"
    end
  end

  actions do
    defaults [:read]

    create :queue do
      accept [
        :task_id,
        :hook_name,
        :hook_id,
        :hook_settings,
        :triggering_column_id,
        :column_hook_id
      ]

      primary? true

      change set_attribute(:queued_at, &DateTime.utc_now/0)
      change set_attribute(:status, :pending)
    end

    update :start do
      accept []

      change set_attribute(:status, :running)
      change set_attribute(:started_at, &DateTime.utc_now/0)
    end

    update :complete do
      accept []

      change set_attribute(:status, :completed)
      change set_attribute(:completed_at, &DateTime.utc_now/0)
    end

    update :fail do
      accept [:error_message]

      change set_attribute(:status, :failed)
      change set_attribute(:completed_at, &DateTime.utc_now/0)
    end

    update :cancel do
      accept [:skip_reason]

      change set_attribute(:status, :cancelled)
      change set_attribute(:completed_at, &DateTime.utc_now/0)
    end

    update :skip do
      accept [:skip_reason]

      change set_attribute(:status, :skipped)
      change set_attribute(:completed_at, &DateTime.utc_now/0)
    end

    read :pending_for_task do
      argument :task_id, :uuid, allow_nil?: false

      filter expr(task_id == ^arg(:task_id) and status == :pending)
      prepare build(sort: [queued_at: :asc])
    end

    read :active_for_task do
      argument :task_id, :uuid, allow_nil?: false

      filter expr(task_id == ^arg(:task_id) and status in [:pending, :running])
      prepare build(sort: [queued_at: :asc])
    end

    read :history_for_task do
      argument :task_id, :uuid, allow_nil?: false

      filter expr(task_id == ^arg(:task_id))
      prepare build(sort: [queued_at: :desc])
    end

    read :for_task_and_column do
      argument :task_id, :uuid, allow_nil?: false
      argument :column_id, :uuid, allow_nil?: false

      filter expr(task_id == ^arg(:task_id) and triggering_column_id == ^arg(:column_id))
      prepare build(sort: [queued_at: :desc])
    end

    read :active_for_task_and_column do
      argument :task_id, :uuid, allow_nil?: false
      argument :column_id, :uuid, allow_nil?: false

      filter expr(
               task_id == ^arg(:task_id) and
                 triggering_column_id == ^arg(:column_id) and
                 status in [:pending, :running]
             )

      prepare build(sort: [queued_at: :asc])
    end
  end

  code_interface do
    define :queue
    define :start
    define :complete
    define :fail
    define :cancel
    define :skip
    define :pending_for_task, args: [:task_id]
    define :active_for_task, args: [:task_id]
    define :history_for_task, args: [:task_id]
    define :for_task_and_column, args: [:task_id, :column_id]
    define :active_for_task_and_column, args: [:task_id, :column_id]
    define :get, action: :read, get_by: [:id]
  end
end
