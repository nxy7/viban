defmodule Viban.KanbanLite.Message do
  @moduledoc """
  Message resource for task conversations (SQLite version).
  """

  use Ash.Resource,
    domain: Viban.KanbanLite,
    data_layer: AshSqlite.DataLayer

  alias Viban.KanbanLite.Message.Changes

  sqlite do
    table "task_events"
    repo Viban.RepoSqlite

    base_filter_sql "type = 'message'"

    references do
      reference :task, on_delete: :delete
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :type, :atom do
      public? true
      allow_nil? false
      default :message
      writable? false
      constraints one_of: [:message]
    end

    attribute :role, :atom do
      public? true
      allow_nil? false
      constraints one_of: [:user, :assistant, :system]
    end

    attribute :content, :string do
      public? true
      allow_nil? false
      constraints min_length: 1, max_length: 100_000
    end

    attribute :status, :atom do
      public? true
      constraints one_of: [:pending, :processing, :completed, :failed]
      default :pending
    end

    attribute :metadata, :map do
      public? true
      default %{}
    end

    attribute :sequence, :integer do
      public? true
      allow_nil? false
      constraints min: 1
    end

    timestamps()
  end

  relationships do
    belongs_to :task, Viban.KanbanLite.Task do
      allow_nil? false
      public? true
      attribute_writable? true
    end
  end

  actions do
    defaults [:read]

    destroy :destroy do
      primary? true
      require_atomic? false
    end

    create :create do
      accept [:role, :content, :status, :metadata, :task_id]
      primary? true

      change Changes.SetSequence
    end

    update :update do
      accept [:content, :status, :metadata]
      primary? true
    end

    update :complete do
      accept [:content, :metadata]
      change set_attribute(:status, :completed)
    end

    update :fail do
      accept [:metadata]
      change set_attribute(:status, :failed)
    end

    update :set_processing do
      change set_attribute(:status, :processing)
    end

    update :append_content do
      accept []
      require_atomic? false

      argument :content, :string do
        allow_nil? false
      end

      change Changes.AppendContent
    end

    read :for_task do
      argument :task_id, :uuid do
        allow_nil? false
      end

      filter expr(task_id == ^arg(:task_id))
      prepare build(sort: [sequence: :asc])
    end

    read :latest_for_task do
      argument :task_id, :uuid do
        allow_nil? false
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
    define :complete
    define :fail
    define :set_processing
    define :append_content, args: [:content]
    define :for_task, args: [:task_id]
    define :latest_for_task, args: [:task_id]
  end
end
