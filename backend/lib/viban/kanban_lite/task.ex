defmodule Viban.KanbanLite.Task do
  @moduledoc """
  Task resource representing a work item in a Kanban column (SQLite version).
  """

  use Ash.Resource,
    domain: Viban.KanbanLite,
    data_layer: AshSqlite.DataLayer,
    notifiers: [Viban.KanbanLite.Task.TaskNotifier]

  alias Viban.KanbanLite.Task.Actions
  alias Viban.KanbanLite.Task.Changes, as: TaskChanges
  alias Viban.KanbanLite.Task.Changes.ProcessDescriptionImages

  sqlite do
    table "tasks"
    repo Viban.RepoSqlite

    references do
      reference :parent_task, on_delete: :delete
    end
  end

  identities do
    identity :unique_worktree_path, [:worktree_path] do
      nils_distinct? true
    end
  end

  attributes do
    uuid_primary_key :id

    # =========================================================================
    # Core Task Attributes
    # =========================================================================

    attribute :title, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 500
    end

    attribute :description, :string do
      public? true
      constraints max_length: 50_000
    end

    attribute :position, :string do
      allow_nil? false
      public? true
      default "a0"
    end

    attribute :priority, :atom do
      public? true
      constraints one_of: [:low, :medium, :high]
      default :medium
    end

    attribute :description_images, {:array, :map} do
      public? true
      default []
    end

    # =========================================================================
    # Git Worktree Attributes
    # =========================================================================

    attribute :worktree_path, :string do
      public? true
      constraints max_length: 1000
    end

    attribute :worktree_branch, :string do
      public? true
      constraints max_length: 255
    end

    attribute :custom_branch_name, :string do
      public? true
      constraints max_length: 255
    end

    # =========================================================================
    # Agent Status Attributes
    # =========================================================================

    attribute :agent_status, :atom do
      public? true
      constraints one_of: [:idle, :thinking, :executing, :error]
      default :idle
    end

    attribute :agent_status_message, :string do
      public? true
      constraints max_length: 1000
    end

    attribute :in_progress, :boolean do
      public? true
      default false
    end

    attribute :error_message, :string do
      public? true
      constraints max_length: 5000
    end

    # =========================================================================
    # Queue Management Attributes
    # =========================================================================

    attribute :queued_at, :utc_datetime do
      public? true
    end

    attribute :queue_priority, :integer do
      public? true
      default 0
    end

    # =========================================================================
    # Pull Request Attributes
    # =========================================================================

    attribute :pr_url, :string do
      public? true
      constraints max_length: 2048
    end

    attribute :pr_number, :integer do
      public? true
      constraints min: 1
    end

    attribute :pr_status, :atom do
      public? true
      constraints one_of: [:open, :merged, :closed, :draft]
    end

    # =========================================================================
    # Parent-Subtask Attributes
    # =========================================================================

    attribute :is_parent, :boolean do
      public? true
      default false
    end

    attribute :subtask_position, :integer do
      public? true
      default 0
      constraints min: 0
    end

    attribute :subtask_generation_status, :atom do
      public? true
      constraints one_of: [:generating, :completed, :failed]
      allow_nil? true
    end

    # =========================================================================
    # Hook Tracking Attributes
    # =========================================================================

    attribute :executed_hooks, {:array, :string} do
      public? true
      default []
    end

    # =========================================================================
    # Message Queue for AI Execution
    # =========================================================================

    attribute :message_queue, {:array, Viban.KanbanLite.Types.MessageQueueEntry} do
      public? true
      default []
    end

    # =========================================================================
    # Periodical Task Attributes
    # =========================================================================

    attribute :auto_start, :boolean do
      public? true
      default false
      allow_nil? false
    end

    timestamps()
  end

  relationships do
    belongs_to :column, Viban.KanbanLite.Column do
      allow_nil? false
      public? true
      attribute_writable? true
    end

    belongs_to :parent_task, Viban.KanbanLite.Task do
      allow_nil? true
      public? true
      attribute_writable? true
    end

    belongs_to :periodical_task, Viban.KanbanLite.PeriodicalTask do
      allow_nil? true
      public? true
      attribute_writable? true
    end

    has_many :subtasks, Viban.KanbanLite.Task do
      public? true
      destination_attribute :parent_task_id
      sort subtask_position: :asc
    end

    has_many :messages, Viban.KanbanLite.Message do
      public? true
      sort sequence: :asc
    end

    has_many :executor_sessions, Viban.KanbanLite.ExecutorSession do
      public? true
    end

    has_many :hook_executions, Viban.KanbanLite.HookExecution do
      public? true
      sort queued_at: :desc
    end
  end

  actions do
    defaults [:read]

    # =========================================================================
    # Primary CRUD Actions
    # =========================================================================

    create :create do
      accept [
        :title,
        :description,
        :priority,
        :column_id,
        :custom_branch_name,
        :description_images,
        :periodical_task_id,
        :auto_start
      ]

      primary? true

      change TaskChanges.SetInitialPosition
      change ProcessDescriptionImages
    end

    update :update do
      accept [
        :title,
        :description,
        :priority,
        :custom_branch_name,
        :description_images
      ]

      primary? true
      require_atomic? false

      change ProcessDescriptionImages
    end

    destroy :destroy do
      primary? true
      require_atomic? false

      change TaskChanges.CleanupDescriptionImages
    end

    # =========================================================================
    # Movement Actions
    # =========================================================================

    update :move do
      accept [:column_id]
      require_atomic? false

      argument :before_task_id, :uuid do
        allow_nil? true
      end

      argument :after_task_id, :uuid do
        allow_nil? true
      end

      change TaskChanges.CalculatePosition
      change TaskChanges.CancelHooksOnMove
    end

    # =========================================================================
    # Worktree Management Actions
    # =========================================================================

    update :assign_worktree do
      accept [:worktree_path, :worktree_branch]
    end

    update :clear_worktree do
      change set_attribute(:worktree_path, nil)
      change set_attribute(:worktree_branch, nil)
    end

    action :create_worktree, :map do
      argument :task_id, :uuid do
        allow_nil? false
      end

      run Actions.CreateWorktree
    end

    # =========================================================================
    # Agent Status Actions
    # =========================================================================

    update :update_agent_status do
      accept [:agent_status, :agent_status_message]
    end

    update :set_in_progress do
      accept [:in_progress]
    end

    update :set_error do
      accept [:agent_status, :error_message, :in_progress]
    end

    update :clear_error do
      change set_attribute(:agent_status, :idle)
      change set_attribute(:error_message, nil)
    end

    # =========================================================================
    # Queue Management Actions
    # =========================================================================

    update :set_queued do
      accept []

      change set_attribute(:queued_at, &DateTime.utc_now/0)
      change set_attribute(:agent_status, :idle)
      change set_attribute(:agent_status_message, "Waiting in queue...")
    end

    update :clear_queued do
      accept []

      change set_attribute(:queued_at, nil)
      change set_attribute(:queue_priority, 0)
    end

    update :set_queue_priority do
      accept [:queue_priority]
    end

    # =========================================================================
    # Pull Request Actions
    # =========================================================================

    update :link_pr do
      accept []

      argument :pr_url, :string do
        allow_nil? false
        constraints max_length: 2048
      end

      argument :pr_number, :integer do
        allow_nil? false
        constraints min: 1
      end

      argument :pr_status, :atom do
        allow_nil? false
        constraints one_of: [:open, :merged, :closed, :draft]
      end

      change set_attribute(:pr_url, arg(:pr_url))
      change set_attribute(:pr_number, arg(:pr_number))
      change set_attribute(:pr_status, arg(:pr_status))
    end

    update :update_pr_status do
      accept [:pr_status]
    end

    update :clear_pr do
      change set_attribute(:pr_url, nil)
      change set_attribute(:pr_number, nil)
      change set_attribute(:pr_status, nil)
    end

    # =========================================================================
    # Subtask Management Actions
    # =========================================================================

    create :create_subtask do
      accept [:title, :description, :priority]

      argument :parent_task_id, :uuid do
        allow_nil? false
      end

      change TaskChanges.SetupSubtask
      change TaskChanges.MarkParentAsParent
    end

    update :set_generation_status do
      accept [:subtask_generation_status]
    end

    update :mark_as_parent do
      change set_attribute(:is_parent, true)
    end

    # =========================================================================
    # Hook Execution Tracking
    # =========================================================================

    update :mark_hook_executed do
      accept []
      require_atomic? false

      argument :column_hook_id, :string do
        allow_nil? false
      end

      change TaskChanges.AddExecutedHook
    end

    # =========================================================================
    # Message Queue Actions
    # =========================================================================

    update :queue_message do
      accept []
      require_atomic? false

      argument :prompt, :string do
        allow_nil? false
      end

      argument :executor_type, :atom do
        default :claude_code
        constraints one_of: [:claude_code, :gemini_cli]
      end

      argument :images, {:array, :map} do
        default []
      end

      change TaskChanges.QueueMessage
    end

    update :pop_message do
      accept []
      require_atomic? false

      change TaskChanges.PopMessage
    end

    update :clear_message_queue do
      change set_attribute(:message_queue, [])
    end

    # =========================================================================
    # LLM Actions
    # =========================================================================

    action :refine, :map do
      argument :task_id, :uuid do
        allow_nil? false
      end

      run Actions.Refine
    end

    action :refine_preview, :map do
      argument :title, :string do
        allow_nil? false
      end

      argument :description, :string do
        allow_nil? true
        default nil
      end

      run Actions.RefinePreview
    end

    action :generate_subtasks, :map do
      argument :task_id, :uuid do
        allow_nil? false
      end

      run Actions.GenerateSubtasks
    end

    action :create_pr, :map do
      argument :task_id, :uuid do
        allow_nil? false
      end

      argument :title, :string do
        allow_nil? false
      end

      argument :body, :string do
        default ""
      end

      argument :base_branch, :string
      run Actions.CreatePR
    end

    # =========================================================================
    # Read Actions
    # =========================================================================

    read :for_column do
      argument :column_id, :uuid do
        allow_nil? false
      end

      filter expr(column_id == ^arg(:column_id))
      prepare build(sort: [position: :asc])
    end

    read :queued do
      filter expr(not is_nil(queued_at))
      prepare build(sort: [queue_priority: :desc, queued_at: :asc])
    end

    read :subtasks do
      argument :parent_task_id, :uuid do
        allow_nil? false
      end

      filter expr(parent_task_id == ^arg(:parent_task_id))
      prepare build(sort: [subtask_position: :asc])
    end
  end

  code_interface do
    # Primary CRUD
    define :create
    define :read
    define :update
    define :destroy
    define :get, action: :read, get_by: [:id]

    # Movement
    define :move

    # Worktree management
    define :assign_worktree
    define :clear_worktree
    define :create_worktree, args: [:task_id]

    # Agent status
    define :update_agent_status
    define :set_in_progress
    define :set_error
    define :clear_error

    # Queue management
    define :set_queued
    define :clear_queued
    define :set_queue_priority

    # Pull request
    define :link_pr, args: [:pr_url, :pr_number, :pr_status]
    define :update_pr_status
    define :clear_pr

    # Subtask management
    define :create_subtask, args: [:parent_task_id]
    define :set_generation_status
    define :mark_as_parent

    # Hook execution tracking
    define :mark_hook_executed, args: [:column_hook_id]

    # Message queue
    define :queue_message, args: [:prompt, :executor_type, :images]
    define :pop_message
    define :clear_message_queue

    # LLM actions
    define :refine, args: [:task_id]
    define :refine_preview, args: [:title, :description]
    define :generate_subtasks, args: [:task_id]
    define :create_pr, args: [:task_id, :title, :body, :base_branch]

    # Read actions
    define :for_column, args: [:column_id]
    define :queued
    define :subtasks, args: [:parent_task_id]
  end
end
