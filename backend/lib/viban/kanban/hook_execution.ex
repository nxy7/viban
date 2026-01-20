defmodule Viban.Kanban.HookExecution do
  @moduledoc """
  Tracks individual hook executions for tasks (SQLite version).
  """

  use Ash.Resource,
    domain: Viban.Kanban,
    data_layer: AshSqlite.DataLayer

  sqlite do
    table "task_events"
    repo Viban.RepoSqlite

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
    end

    attribute :hook_name, :string do
      allow_nil? false
      public? true
    end

    attribute :hook_id, :string do
      allow_nil? false
      public? true
    end

    attribute :status, :atom do
      allow_nil? false
      default :pending
      public? true
      constraints one_of: [:pending, :running, :completed, :failed, :cancelled, :skipped]
    end

    attribute :skip_reason, :atom do
      public? true
      constraints one_of: [:error, :disabled, :column_change, :server_restart, :user_cancelled]
    end

    attribute :error_message, :string do
      public? true
    end

    attribute :hook_settings, :map do
      default %{}
      public? true
    end

    attribute :queued_at, :utc_datetime_usec do
      allow_nil? false
      public? true
    end

    attribute :started_at, :utc_datetime_usec do
      public? true
    end

    attribute :completed_at, :utc_datetime_usec do
      public? true
    end

    attribute :triggering_column_id, :uuid do
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :task, Viban.Kanban.Task do
      allow_nil? false
      public? true
      attribute_writable? true
    end

    belongs_to :column_hook, Viban.Kanban.ColumnHook do
      public? true
      attribute_writable? true
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
