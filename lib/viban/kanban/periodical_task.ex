defmodule Viban.Kanban.PeriodicalTask do
  @moduledoc """
  Resource for scheduling recurring tasks (SQLite version).
  """

  use Ash.Resource,
    domain: Viban.Kanban,
    data_layer: AshSqlite.DataLayer

  alias Viban.Kanban.PeriodicalTask.Changes
  alias Viban.Kanban.PeriodicalTask.Validations

  sqlite do
    table "periodical_tasks"
    repo Viban.RepoSqlite
  end

  attributes do
    uuid_primary_key :id

    attribute :title, :string do
      allow_nil? false
      public? true
    end

    attribute :description, :string do
      public? true
    end

    attribute :schedule, :string do
      allow_nil? false
      public? true
    end

    attribute :executor, :atom do
      public? true
      constraints one_of: [:claude_code, :gemini_cli, :codex, :opencode, :cursor_agent]
      default :claude_code
    end

    attribute :execution_count, :integer do
      public? true
      default 0
      allow_nil? false
    end

    attribute :last_executed_at, :utc_datetime_usec do
      public? true
    end

    attribute :next_execution_at, :utc_datetime_usec do
      public? true
    end

    attribute :enabled, :boolean do
      public? true
      default true
      allow_nil? false
    end

    attribute :last_created_task_id, :uuid do
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :board, Viban.Kanban.Board do
      allow_nil? false
      public? true
      attribute_writable? true
    end

    has_many :tasks, Viban.Kanban.Task do
      public? true
    end
  end

  actions do
    defaults [:read]

    read :for_board do
      argument :board_id, :uuid, allow_nil?: false
      filter expr(board_id == ^arg(:board_id))
      prepare build(sort: [title: :asc])
    end

    create :create do
      accept [:title, :description, :schedule, :executor, :enabled, :board_id]
      primary? true

      validate Validations.ValidCronExpression
      change Changes.CalculateNextExecution
    end

    update :update do
      accept [:title, :description, :schedule, :executor, :enabled]
      primary? true
      require_atomic? false

      validate Validations.ValidCronExpression
      change Changes.CalculateNextExecution
    end

    update :record_execution do
      accept []
      require_atomic? false

      argument :task_id, :uuid do
        allow_nil? false
      end

      change Changes.RecordExecution
    end

    destroy :destroy do
      primary? true
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :destroy
    define :record_execution, args: [:task_id]
    define :get, action: :read, get_by: [:id]
    define :for_board, args: [:board_id]
  end
end
