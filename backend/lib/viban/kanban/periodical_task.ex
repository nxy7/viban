defmodule Viban.Kanban.PeriodicalTask do
  @moduledoc """
  Resource for scheduling recurring tasks that run automatically at specified intervals.

  Each execution creates a unique task with title "#N {Title}" where N is the execution number.
  Tasks are created in the Todo column and can have `auto_start: true` to be moved to In Progress
  after Todo hooks complete.

  ## Scheduling

  Uses cron expressions (e.g., "0 9 * * 1-5" for weekdays at 9 AM).
  The scheduler checks every 60 seconds for due tasks.

  ## Skip-If-Running

  If the previous execution's task is still in "In Progress", the next execution is skipped.
  """

  use Ash.Resource,
    domain: Viban.Kanban,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshTypescript.Resource]

  alias Viban.Kanban.PeriodicalTask.Changes
  alias Viban.Kanban.PeriodicalTask.Validations

  typescript do
    type_name("PeriodicalTask")
  end

  postgres do
    table "periodical_tasks"
    repo Viban.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :title, :string do
      allow_nil? false
      public? true
      description "Title template for generated tasks"
    end

    attribute :description, :string do
      public? true
      description "Description template for generated tasks"
    end

    attribute :schedule, :string do
      allow_nil? false
      public? true
      description "Cron expression (e.g., '0 9 * * 1-5' for weekdays at 9 AM)"
    end

    attribute :executor, :atom do
      public? true
      constraints one_of: [:claude_code, :gemini_cli, :codex, :opencode, :cursor_agent]
      default :claude_code
      description "AI executor to use for generated tasks"
    end

    attribute :execution_count, :integer do
      public? true
      default 0
      allow_nil? false
      description "Number of times this periodical task has been executed"
    end

    attribute :last_executed_at, :utc_datetime_usec do
      public? true
      description "When the last task was created"
    end

    attribute :next_execution_at, :utc_datetime_usec do
      public? true
      description "When the next task will be created"
    end

    attribute :enabled, :boolean do
      public? true
      default true
      allow_nil? false
      description "Whether this periodical task is active"
    end

    attribute :last_created_task_id, :uuid do
      public? true
      description "ID of the most recently created task (for skip-if-running logic)"
    end

    timestamps()
  end

  relationships do
    belongs_to :board, Viban.Kanban.Board do
      allow_nil? false
      public? true
      attribute_writable? true
      description "The board this periodical task belongs to"
    end

    has_many :tasks, Viban.Kanban.Task do
      public? true
      description "All tasks spawned by this periodical task"
    end
  end

  actions do
    defaults [:read]

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
      description "Record that an execution occurred and calculate next run time"
      require_atomic? false

      argument :task_id, :uuid do
        allow_nil? false
        description "ID of the task that was created"
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
  end
end
