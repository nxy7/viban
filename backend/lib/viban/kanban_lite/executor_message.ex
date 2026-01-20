defmodule Viban.KanbanLite.ExecutorMessage do
  @moduledoc """
  Ash Resource for storing executor messages (SQLite version).
  """

  use Ash.Resource,
    domain: Viban.KanbanLite,
    data_layer: AshSqlite.DataLayer

  sqlite do
    table "task_events"
    repo Viban.RepoSqlite

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
    end

    attribute :role, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:user, :assistant, :system, :tool]
    end

    attribute :content, :string do
      allow_nil? false
      public? true
    end

    attribute :metadata, :map do
      public? true
      default %{}
    end

    attribute :session_id, :uuid do
      public? true
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
