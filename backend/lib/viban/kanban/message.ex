defmodule Viban.Kanban.Message do
  @moduledoc """
  Message resource for storing conversation messages between users and LLM agents.

  Each message belongs to a task and represents a single exchange in the conversation.
  Messages can be from users, assistants (LLM), or system prompts.

  ## Roles

  - `:user` - Messages from the human user
  - `:assistant` - Messages from the LLM agent
  - `:system` - System-generated messages (e.g., notifications, errors)

  ## Statuses

  - `:pending` - Message awaiting processing
  - `:processing` - Message currently being processed
  - `:completed` - Message successfully processed
  - `:failed` - Message processing failed

  ## Ordering

  Messages within a task are ordered by their `sequence` number, which is
  automatically assigned on creation. The sequence is 1-indexed and increases
  monotonically within each task's conversation.

  ## Metadata

  The `metadata` map can store additional information such as:
  - Token counts (input/output)
  - Model information
  - Error details for failed messages
  - Tool call information
  """

  use Ash.Resource,
    domain: Viban.Kanban,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshTypescript.Resource]

  alias Viban.Kanban.Message.Changes

  # Type definitions for documentation
  @type role :: :user | :assistant | :system
  @type status :: :pending | :processing | :completed | :failed

  typescript do
    type_name("Message")
  end

  postgres do
    table "messages"
    repo Viban.Repo

    references do
      reference :task, on_delete: :delete
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :role, :atom do
      public? true
      allow_nil? false
      constraints one_of: [:user, :assistant, :system]
      description "Message author role (user, assistant, or system)"
    end

    attribute :content, :string do
      public? true
      allow_nil? false
      constraints min_length: 1, max_length: 100_000
      description "Message content (supports markdown)"
    end

    attribute :status, :atom do
      public? true
      constraints one_of: [:pending, :processing, :completed, :failed]
      default :pending
      description "Processing status of the message"
    end

    attribute :metadata, :map do
      public? true
      default %{}
      description "Additional metadata (token counts, model info, errors, etc.)"
    end

    attribute :sequence, :integer do
      public? true
      allow_nil? false
      constraints min: 1
      description "Order within the task conversation (1-indexed)"
    end

    timestamps()
  end

  relationships do
    belongs_to :task, Viban.Kanban.Task do
      allow_nil? false
      public? true
      attribute_writable? true
      description "The task this message belongs to"
    end
  end

  actions do
    defaults [:read]

    destroy :destroy do
      primary? true
      require_atomic? false
    end

    create :create do
      description "Create a new message in a task conversation"

      accept [:role, :content, :status, :metadata, :task_id]
      primary? true

      change Changes.SetSequence
    end

    update :update do
      description "Update message content, status, or metadata"

      accept [:content, :status, :metadata]
      primary? true
    end

    update :complete do
      description "Mark message as completed with optional content update"

      accept [:content, :metadata]

      change set_attribute(:status, :completed)
    end

    update :fail do
      description "Mark message as failed with optional error metadata"

      accept [:metadata]

      change set_attribute(:status, :failed)
    end

    update :set_processing do
      description "Mark message as currently being processed"

      change set_attribute(:status, :processing)
    end

    update :append_content do
      description "Append content to existing message (for streaming responses)"

      accept []
      require_atomic? false

      argument :content, :string do
        allow_nil? false
        description "Content to append"
      end

      change Changes.AppendContent
    end

    read :for_task do
      description "List all messages for a specific task, ordered by sequence"

      argument :task_id, :uuid do
        allow_nil? false
        description "The task's ID"
      end

      filter expr(task_id == ^arg(:task_id))
      prepare build(sort: [sequence: :asc])
    end

    read :latest_for_task do
      description "Get the most recent message for a task"

      argument :task_id, :uuid do
        allow_nil? false
        description "The task's ID"
      end

      filter expr(task_id == ^arg(:task_id))
      prepare build(sort: [sequence: :desc], limit: 1)
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :destroy
    define :get, action: :read, get_by: [:id]

    # Status transitions
    define :complete
    define :fail
    define :set_processing

    # Content manipulation
    define :append_content, args: [:content]

    # Query actions
    define :for_task, args: [:task_id]
    define :latest_for_task, args: [:task_id]
  end
end
