defmodule Viban.Kanban.Column do
  @moduledoc """
  Column resource representing a column in a Kanban board (SQLite version).
  """

  use Ash.Resource,
    domain: Viban.Kanban,
    data_layer: AshSqlite.DataLayer

  alias Viban.Kanban.Column.Actions
  alias Viban.Kanban.Column.Changes

  sqlite do
    table "columns"
    repo Viban.RepoSqlite
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 100
    end

    attribute :position, :integer do
      allow_nil? false
      public? true
      default 0
      constraints min: 0
    end

    attribute :color, :string do
      public? true
      default "#6366f1"
      constraints match: ~r/^#[0-9A-Fa-f]{6}$/
    end

    attribute :settings, :map do
      public? true
      default %{}
    end

    timestamps()
  end

  identities do
    identity :unique_name_per_board, [:board_id, :name]
    identity :unique_position_per_board, [:board_id, :position]
  end

  relationships do
    belongs_to :board, Viban.Kanban.Board do
      allow_nil? false
      public? true
      attribute_writable? true
    end

    has_many :tasks, Viban.Kanban.Task do
      public? true
      sort position: :asc
    end

    has_many :column_hooks, Viban.Kanban.ColumnHook do
      public? true
    end
  end

  actions do
    defaults [:read]

    create :create do
      accept [:name, :position, :color, :settings, :board_id]
      primary? true
    end

    update :update do
      accept [:name, :position, :color, :settings]
      primary? true
    end

    update :update_settings do
      accept []
      require_atomic? false

      argument :settings, :map do
        allow_nil? false
      end

      change Changes.MergeSettings
    end

    destroy :destroy do
      primary? true
    end

    read :for_board do
      argument :board_id, :uuid do
        allow_nil? false
      end

      filter expr(board_id == ^arg(:board_id))
      prepare build(sort: [position: :asc])
    end

    action :delete_all_tasks, :integer do
      argument :column_id, :uuid do
        allow_nil? false
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
