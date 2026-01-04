defmodule Viban.Kanban.Column do
  @moduledoc """
  Column resource representing a column in a Kanban board.

  Columns contain tasks and can have associated hooks that trigger
  when tasks enter or leave the column.

  ## Uniqueness

  Column names must be unique within a board, and positions must not overlap.

  ## Settings

  The `settings` map supports:
  - `max_concurrent_tasks` - Maximum tasks that can be actively worked on
  - `hooks_enabled` - Whether hooks should trigger for this column
  - Any additional custom settings

  ## Cascade Deletion

  When a column is deleted, all tasks and column hooks within it are
  automatically deleted.
  """

  use Ash.Resource,
    domain: Viban.Kanban,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshTypescript.Resource]

  alias Viban.Kanban.Column.{Actions, Changes}

  @type color :: String.t()
  @type settings :: %{optional(atom()) => term()}

  typescript do
    type_name("Column")
  end

  postgres do
    table "columns"
    repo Viban.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 100
      description "Column display name (unique within board)"
    end

    attribute :position, :integer do
      allow_nil? false
      public? true
      default 0
      constraints min: 0
      description "Order position within the board (0-indexed)"
    end

    attribute :color, :string do
      public? true
      default "#6366f1"
      constraints match: ~r/^#[0-9A-Fa-f]{6}$/
      description "Display color in hex format (e.g., #6366f1)"
    end

    attribute :settings, :map do
      public? true
      default %{}
      description "Column-specific settings (max_concurrent_tasks, hooks_enabled, etc.)"
    end

    timestamps()
  end

  identities do
    identity :unique_name_per_board, [:board_id, :name] do
      message "A column with this name already exists in this board"
    end

    identity :unique_position_per_board, [:board_id, :position] do
      message "A column with this position already exists in this board"
    end
  end

  relationships do
    belongs_to :board, Viban.Kanban.Board do
      allow_nil? false
      public? true
      attribute_writable? true
      description "The board this column belongs to"
    end

    has_many :tasks, Viban.Kanban.Task do
      public? true
      sort position: :asc
      description "Tasks in this column, ordered by position"
    end

    has_many :column_hooks, Viban.Kanban.ColumnHook do
      public? true
      description "Hooks attached to this column"
    end
  end

  actions do
    defaults [:read]

    create :create do
      description "Create a new column in a board"

      accept [:name, :position, :color, :settings, :board_id]
      primary? true
    end

    update :update do
      description "Update column properties"

      accept [:name, :position, :color, :settings]
      primary? true
    end

    update :update_settings do
      description "Merge new settings with existing settings (shallow merge)"

      accept []
      require_atomic? false

      argument :settings, :map do
        allow_nil? false
        description "Settings to merge with existing settings"
      end

      change Changes.MergeSettings
    end

    destroy :destroy do
      description "Delete column and all its tasks"

      primary? true
    end

    read :for_board do
      description "List all columns for a specific board"

      argument :board_id, :uuid do
        allow_nil? false
        description "The board's ID"
      end

      filter expr(board_id == ^arg(:board_id))
      prepare build(sort: [position: :asc])
    end

    action :delete_all_tasks, :integer do
      description "Delete all tasks in this column. Returns the number of tasks deleted."

      argument :column_id, :uuid do
        allow_nil? false
        description "The column's ID"
      end

      run Actions.DeleteAllTasks
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :destroy
    define :update_settings, args: [:settings]
    define :for_board, args: [:board_id]
    define :get, action: :read, get_by: [:id]
    define :delete_all_tasks, args: [:column_id]
  end
end
