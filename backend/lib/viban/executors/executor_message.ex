defmodule Viban.Executors.ExecutorMessage do
  @moduledoc """
  Ash Resource for storing executor messages.

  Messages are individual events during an executor session:
  - User prompts sent to the executor
  - Assistant responses from the LLM
  - System events (started, completed, errors)
  - Tool usage events

  This enables message persistence so users can see previous conversations
  when reopening a task.
  """

  use Ash.Resource,
    domain: Viban.Kanban,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "task_events"
    repo Viban.Repo

    base_filter_sql "type = 'executor_output'"
  end

  attributes do
    uuid_primary_key :id

    attribute :type, :atom do
      allow_nil? false
      default :executor_output
      writable? false
      public? true
      constraints one_of: [:executor_output]
      description "Event type discriminator (always 'executor_output' for this resource)"
    end

    attribute :role, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:user, :assistant, :system, :tool]
      description "The role/sender of the message"
    end

    attribute :content, :string do
      allow_nil? false
      public? true
      description "The message content (may be markdown for assistant messages)"
    end

    attribute :metadata, :map do
      public? true
      default %{}
      description "Additional metadata (tool name, exit code, etc.)"
    end

    attribute :session_id, :uuid do
      public? true
      description "Links this output to its executor session"
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
    defaults [:read, :destroy]

    create :create do
      accept [:task_id, :session_id, :role, :content, :metadata]
      primary? true
    end

    read :for_session do
      argument :session_id, :uuid, allow_nil?: false
      filter expr(session_id == ^arg(:session_id))
      prepare build(sort: [inserted_at: :asc])
    end

    read :for_task do
      argument :task_id, :uuid, allow_nil?: false
      filter expr(task_id == ^arg(:task_id))
      prepare build(sort: [inserted_at: :asc])
    end
  end

  code_interface do
    define :create
    define :read
    define :for_session, args: [:session_id]
    define :for_task, args: [:task_id]
  end
end
