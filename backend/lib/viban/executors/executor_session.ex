defmodule Viban.Executors.ExecutorSession do
  @moduledoc """
  Ash Resource for tracking executor sessions.

  An executor session represents a single execution of an AI coding agent
  for a specific task. Sessions track:
  - When the executor was started/completed
  - The executor type used
  - Exit status and any errors
  - Associated logs

  This allows for reviewing past executor runs and their outputs.
  """

  use Ash.Resource,
    domain: Viban.Kanban,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshTypescript.Resource]

  typescript do
    type_name("ExecutorSession")
  end

  postgres do
    table "task_events"
    repo Viban.Repo

    base_filter_sql "type = 'session'"

    references do
      reference :task, on_delete: :delete
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :type, :atom do
      allow_nil? false
      default :session
      writable? false
      public? true
      constraints one_of: [:session]
      description "Event type discriminator (always 'session' for this resource)"
    end

    attribute :executor_type, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :claude_code,
                    :gemini_cli,
                    :codex,
                    :opencode,
                    :api_anthropic,
                    :api_openai
                  ]

      description "The type of executor used for this session"
    end

    attribute :prompt, :string do
      allow_nil? false
      public? true
      description "The prompt/instruction given to the executor"
    end

    attribute :status, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:pending, :running, :completed, :failed, :stopped]
      default :pending
      description "Current status of the executor session"
    end

    attribute :exit_code, :integer do
      public? true
      description "Exit code from the executor process (if applicable)"
    end

    attribute :error_message, :string do
      public? true
      description "Error message if the session failed"
    end

    attribute :working_directory, :string do
      public? true
      description "Working directory used for this session"
    end

    attribute :started_at, :utc_datetime_usec do
      public? true
      description "When the executor was started"
    end

    attribute :completed_at, :utc_datetime_usec do
      public? true
      description "When the executor completed/failed/stopped"
    end

    attribute :metadata, :map do
      public? true
      default %{}
      description "Additional metadata about the session"
    end

    timestamps()
  end

  relationships do
    belongs_to :task, Viban.Kanban.Task do
      allow_nil? false
      public? true
      attribute_writable? true
    end
  end

  actions do
    defaults [:read]

    destroy :destroy do
      primary? true
    end

    create :create do
      accept [:task_id, :executor_type, :prompt, :working_directory, :metadata]
      primary? true

      change set_attribute(:started_at, &DateTime.utc_now/0)
    end

    update :start do
      change set_attribute(:status, :running)
      change set_attribute(:started_at, &DateTime.utc_now/0)
    end

    update :complete do
      accept [:exit_code]

      change set_attribute(:status, :completed)
      change set_attribute(:completed_at, &DateTime.utc_now/0)
    end

    update :fail do
      accept [:exit_code, :error_message]

      change set_attribute(:status, :failed)
      change set_attribute(:completed_at, &DateTime.utc_now/0)
    end

    update :stop do
      change set_attribute(:status, :stopped)
      change set_attribute(:completed_at, &DateTime.utc_now/0)
    end

    read :for_task do
      argument :task_id, :uuid, allow_nil?: false
      filter expr(task_id == ^arg(:task_id))
    end

    read :recent do
      argument :limit, :integer, default: 10
      prepare build(sort: [inserted_at: :desc], limit: arg(:limit))
    end
  end

  code_interface do
    define :create
    define :read
    define :destroy
    define :start
    define :complete
    define :fail
    define :stop
    define :for_task, args: [:task_id]
    define :recent, args: [:limit]
    define :get, action: :read, get_by: [:id]
  end
end
