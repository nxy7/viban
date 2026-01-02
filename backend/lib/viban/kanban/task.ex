defmodule Viban.Kanban.Task do
  @moduledoc """
  Task resource representing a work item in a Kanban column.

  Tasks support AI agent integration for automated processing,
  git worktrees for isolated development, and parent-subtask hierarchies.

  ## Features

  - AI agent status tracking for LLM-powered automation
  - Git worktree management for isolated development environments
  - Parent-subtask relationships for breaking down complex work
  - Pull request tracking for development workflow integration
  - Image attachments in task descriptions
  - Hook execution tracking for automation workflows

  ## Agent Status Lifecycle

  Tasks go through these agent states:
  - `:idle` - No agent activity
  - `:thinking` - Agent is processing/planning
  - `:executing` - Agent is running commands/making changes
  - `:error` - Agent encountered an error

  ## Queue Management

  Tasks can be queued for processing with priority ordering:
  - Higher `queue_priority` values are processed first
  - Tasks with equal priority are processed FIFO by `queued_at`

  ## Cascade Deletion

  When a task is deleted, all subtasks, messages, and executor sessions
  are automatically deleted.
  """

  use Ash.Resource,
    domain: Viban.Kanban,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshTypescript.Resource],
    notifiers: [Viban.Kanban.Notifiers.TaskNotifier]

  alias Viban.Kanban.Task.Actions
  alias Viban.Kanban.Task.Changes, as: TaskChanges

  # Type definitions for documentation
  @type agent_status :: :idle | :thinking | :executing | :error
  @type priority :: :low | :medium | :high
  @type pr_status :: :open | :merged | :closed | :draft
  @type subtask_generation_status :: :generating | :completed | :failed

  typescript do
    type_name("Task")
  end

  postgres do
    table "tasks"
    repo Viban.Repo

    references do
      reference :parent_task, on_delete: :delete
    end
  end

  identities do
    identity :unique_worktree_path, [:worktree_path] do
      message "This worktree path is already assigned to another task"
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
      description "Task title"
    end

    attribute :description, :string do
      public? true
      constraints max_length: 50_000
      description "Task description (supports markdown)"
    end

    attribute :position, :float do
      allow_nil? false
      public? true
      default 0.0

      description "Order position within the column (supports fractional and negative values for reordering)"
    end

    attribute :priority, :atom do
      public? true
      constraints one_of: [:low, :medium, :high]
      default :medium
      description "Task priority level"
    end

    attribute :description_images, {:array, :map} do
      public? true
      default []
      description "Image metadata: [{id, path, name}]"
    end

    # =========================================================================
    # Git Worktree Attributes
    # =========================================================================

    attribute :worktree_path, :string do
      public? true
      constraints max_length: 1000
      description "Path to the git worktree for isolated development"
    end

    attribute :worktree_branch, :string do
      public? true
      constraints max_length: 255
      description "Branch name created for this task in the worktree"
    end

    attribute :custom_branch_name, :string do
      public? true
      constraints max_length: 255
      description "Optional custom branch name (used when creating worktree)"
    end

    # =========================================================================
    # Agent Status Attributes
    # =========================================================================

    attribute :agent_status, :atom do
      public? true
      constraints one_of: [:idle, :thinking, :executing, :error]
      default :idle
      description "Current state of the LLM agent"
    end

    attribute :agent_status_message, :string do
      public? true
      constraints max_length: 1000
      description "Human-readable status message from the agent"
    end

    attribute :in_progress, :boolean do
      public? true
      default false
      description "Whether the TaskActor is actively working on this task"
    end

    attribute :error_message, :string do
      public? true
      constraints max_length: 5000
      description "Error message when task is in error state"
    end

    # =========================================================================
    # Queue Management Attributes
    # =========================================================================

    attribute :queued_at, :utc_datetime do
      public? true
      description "When task entered the queue (nil if not queued)"
    end

    attribute :queue_priority, :integer do
      public? true
      default 0
      description "Queue priority (higher = higher priority, 0 = normal FIFO)"
    end

    # =========================================================================
    # Pull Request Attributes
    # =========================================================================

    attribute :pr_url, :string do
      public? true
      constraints max_length: 2048
      description "URL to the pull request"
    end

    attribute :pr_number, :integer do
      public? true
      constraints min: 1
      description "PR number in the repository"
    end

    attribute :pr_status, :atom do
      public? true
      constraints one_of: [:open, :merged, :closed, :draft]
      description "Current status of the PR"
    end

    # =========================================================================
    # Parent-Subtask Attributes
    # =========================================================================

    attribute :is_parent, :boolean do
      public? true
      default false
      description "Whether this task has subtasks"
    end

    attribute :subtask_position, :integer do
      public? true
      default 0
      constraints min: 0
      description "Position within parent's subtask list"
    end

    attribute :subtask_generation_status, :atom do
      public? true
      constraints one_of: [:generating, :completed, :failed]
      allow_nil? true
      description "Status of AI subtask generation"
    end

    # =========================================================================
    # Hook Tracking Attributes
    # =========================================================================

    attribute :executed_hooks, {:array, :string} do
      public? true
      default []
      description "Column hook IDs already executed (for execute_once tracking)"
    end

    # =========================================================================
    # Message Queue for AI Execution
    # =========================================================================

    attribute :message_queue, {:array, Viban.Kanban.Types.MessageQueueEntry} do
      public? true
      default []
      description "Queue of messages waiting to be processed by Execute AI hook"
    end

    timestamps()
  end

  relationships do
    belongs_to :column, Viban.Kanban.Column do
      allow_nil? false
      public? true
      attribute_writable? true
      description "The column this task belongs to"
    end

    belongs_to :parent_task, Viban.Kanban.Task do
      allow_nil? true
      public? true
      attribute_writable? true
      description "Parent task if this is a subtask"
    end

    has_many :subtasks, Viban.Kanban.Task do
      public? true
      destination_attribute :parent_task_id
      sort subtask_position: :asc
      description "Subtasks of this parent task, ordered by position"
    end

    has_many :messages, Viban.Kanban.Message do
      public? true
      sort sequence: :asc
      description "Conversation messages for this task, ordered by sequence"
    end

    has_many :executor_sessions, Viban.Executors.ExecutorSession do
      public? true
      description "Executor sessions for this task"
    end

    has_many :hook_executions, Viban.Kanban.HookExecution do
      public? true
      sort queued_at: :desc
      description "Hook execution history for this task"
    end
  end

  actions do
    defaults [:read]

    # =========================================================================
    # Primary CRUD Actions
    # =========================================================================

    create :create do
      description "Create a new task in a column"

      accept [
        :title,
        :description,
        :position,
        :priority,
        :column_id,
        :custom_branch_name,
        :description_images
      ]

      primary? true

      change Viban.Kanban.Changes.ProcessDescriptionImages
    end

    update :update do
      description "Update task properties"

      accept [
        :title,
        :description,
        :position,
        :priority,
        :custom_branch_name,
        :description_images
      ]

      primary? true
      require_atomic? false

      change Viban.Kanban.Changes.ProcessDescriptionImages
    end

    destroy :destroy do
      description "Delete task and all associated data"

      primary? true
      require_atomic? false

      change Viban.Kanban.Changes.CleanupDescriptionImages
    end

    # =========================================================================
    # Movement Actions
    # =========================================================================

    update :move do
      description "Move task to different column or position (for drag & drop)"

      accept [:column_id, :position]
      require_atomic? false

      change TaskChanges.CancelHooksOnMove
    end

    # =========================================================================
    # Worktree Management Actions
    # =========================================================================

    update :assign_worktree do
      description "Assign git worktree to task (called by TaskActor)"

      accept [:worktree_path, :worktree_branch]
    end

    update :clear_worktree do
      description "Clear worktree fields after cleanup"

      change set_attribute(:worktree_path, nil)
      change set_attribute(:worktree_branch, nil)
    end

    action :create_worktree, :map do
      description "Create a git worktree for this task"

      argument :task_id, :uuid do
        allow_nil? false
        description "ID of the task to create worktree for"
      end

      run Actions.CreateWorktree
    end

    # =========================================================================
    # Agent Status Actions
    # =========================================================================

    update :update_agent_status do
      description "Update agent status (called by LLM service)"

      accept [:agent_status, :agent_status_message]
    end

    update :set_in_progress do
      description "Set in_progress flag (called by TaskActor)"

      accept [:in_progress]
    end

    update :set_error do
      description "Set error state when hook or agent fails"

      accept [:agent_status, :error_message, :in_progress]
    end

    update :clear_error do
      description "Clear error state and reset to idle"

      change set_attribute(:agent_status, :idle)
      change set_attribute(:error_message, nil)
    end

    # =========================================================================
    # Queue Management Actions
    # =========================================================================

    update :set_queued do
      description "Mark task as queued for processing"

      accept []

      change set_attribute(:queued_at, &DateTime.utc_now/0)
      change set_attribute(:agent_status, :idle)
      change set_attribute(:agent_status_message, "Waiting in queue...")
    end

    update :clear_queued do
      description "Clear queue status after processing"

      accept []

      change set_attribute(:queued_at, nil)
      change set_attribute(:queue_priority, 0)
    end

    update :set_queue_priority do
      description "Set queue priority for task ordering"

      accept [:queue_priority]
    end

    # =========================================================================
    # Pull Request Actions
    # =========================================================================

    update :link_pr do
      description "Link a pull request to this task"

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
      description "Update PR status (open, merged, closed, draft)"

      accept [:pr_status]
    end

    update :clear_pr do
      description "Clear PR information from task"

      change set_attribute(:pr_url, nil)
      change set_attribute(:pr_number, nil)
      change set_attribute(:pr_status, nil)
    end

    # =========================================================================
    # Subtask Management Actions
    # =========================================================================

    create :create_subtask do
      description "Create a subtask under a parent task"

      accept [:title, :description, :priority]

      argument :parent_task_id, :uuid do
        allow_nil? false
        description "ID of the parent task"
      end

      change TaskChanges.SetupSubtask
      change TaskChanges.MarkParentAsParent
    end

    update :set_generation_status do
      description "Set AI subtask generation status"

      accept [:subtask_generation_status]
    end

    update :mark_as_parent do
      description "Mark task as having subtasks"

      change set_attribute(:is_parent, true)
    end

    # =========================================================================
    # Hook Execution Tracking
    # =========================================================================

    update :mark_hook_executed do
      description "Mark a hook as executed (for execute_once tracking)"

      accept []
      require_atomic? false

      argument :column_hook_id, :string do
        allow_nil? false
        description "ID of the column hook that was executed"
      end

      change TaskChanges.AddExecutedHook
    end

    # =========================================================================
    # Message Queue Actions
    # =========================================================================

    update :queue_message do
      description "Add a message to the task's message queue for AI processing"

      accept []
      require_atomic? false

      argument :prompt, :string do
        allow_nil? false
        description "The user's message/prompt"
      end

      argument :executor_type, :atom do
        default :claude_code
        constraints one_of: [:claude_code, :gemini_cli]
        description "The executor to use"
      end

      argument :images, {:array, :map} do
        default []
        description "Image attachments"
      end

      change TaskChanges.QueueMessage
    end

    update :pop_message do
      description "Remove and return the first message from the queue"

      accept []
      require_atomic? false

      change TaskChanges.PopMessage
    end

    update :clear_message_queue do
      description "Clear all queued messages"

      change set_attribute(:message_queue, [])
    end

    # =========================================================================
    # LLM Actions
    # =========================================================================

    action :refine, :map do
      description "Refine task description using LLM"

      argument :task_id, :uuid do
        allow_nil? false
        description "ID of the task to refine"
      end

      run Actions.Refine
    end

    action :refine_preview, :map do
      description "Preview refined description without saving"

      argument :title, :string do
        allow_nil? false
        description "Task title to refine"
      end

      argument :description, :string do
        allow_nil? true
        default nil
        description "Optional task description to include in refinement"
      end

      run Actions.RefinePreview
    end

    action :generate_subtasks, :map do
      description "Generate subtasks for a parent task using AI"

      argument :task_id, :uuid do
        allow_nil? false
        description "ID of the parent task"
      end

      run Actions.GenerateSubtasks
    end

    action :create_pr, :map do
      description "Create a GitHub pull request for this task"

      argument :task_id, :uuid do
        allow_nil? false
        description "ID of the task to create PR for"
      end

      argument :title, :string do
        allow_nil? false
        description "PR title"
      end

      argument :body, :string do
        default ""
        description "PR description/body"
      end

      argument :base_branch, :string do
        description "Base branch for the PR (defaults to repo default)"
      end

      run Actions.CreatePR
    end

    # =========================================================================
    # Read Actions
    # =========================================================================

    read :for_column do
      description "List all tasks in a specific column"

      argument :column_id, :uuid do
        allow_nil? false
        description "The column's ID"
      end

      filter expr(column_id == ^arg(:column_id))
      prepare build(sort: [position: :asc])
    end

    read :queued do
      description "List all queued tasks, ordered by priority then queue time"

      filter expr(not is_nil(queued_at))
      prepare build(sort: [queue_priority: :desc, queued_at: :asc])
    end

    read :subtasks do
      description "List all subtasks for a parent task"

      argument :parent_task_id, :uuid do
        allow_nil? false
        description "ID of the parent task"
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
