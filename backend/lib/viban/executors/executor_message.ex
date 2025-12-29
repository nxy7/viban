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
    domain: Viban.Executors,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "executor_messages"
    repo Viban.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :role, :atom do
      allow_nil? false
      constraints one_of: [:user, :assistant, :system, :tool]
      description "The role/sender of the message"
    end

    attribute :content, :string do
      allow_nil? false
      description "The message content (may be markdown for assistant messages)"
    end

    attribute :metadata, :map do
      default %{}
      description "Additional metadata (tool name, exit code, etc.)"
    end

    create_timestamp :inserted_at
  end

  relationships do
    belongs_to :session, Viban.Executors.ExecutorSession do
      allow_nil? false
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:session_id, :role, :content, :metadata]
      primary? true
    end

    read :for_session do
      argument :session_id, :uuid, allow_nil?: false
      filter expr(session_id == ^arg(:session_id))
      prepare build(sort: [inserted_at: :asc])
    end

    read :recent_for_task do
      argument :task_id, :uuid, allow_nil?: false
      argument :limit, :integer, default: 100

      prepare build(sort: [inserted_at: :asc])
    end
  end

  code_interface do
    define :create
    define :read
    define :for_session, args: [:session_id]
    define :recent_for_task, args: [:task_id]
  end
end
