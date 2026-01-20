defmodule Viban.KanbanLite.TaskTemplate do
  @moduledoc """
  Task templates for quick task creation (SQLite version).
  """

  use Ash.Resource,
    domain: Viban.KanbanLite,
    data_layer: AshSqlite.DataLayer

  sqlite do
    table "task_templates"
    repo Viban.RepoSqlite
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints max_length: 100
    end

    attribute :description_template, :string do
      public? true
      constraints max_length: 10_000
    end

    attribute :position, :integer do
      public? true
      default 0
      allow_nil? false
    end

    timestamps()
  end

  relationships do
    belongs_to :board, Viban.KanbanLite.Board do
      allow_nil? false
      public? true
      attribute_writable? true
    end
  end

  actions do
    defaults [:read]

    read :for_board do
      argument :board_id, :uuid, allow_nil?: false
      filter expr(board_id == ^arg(:board_id))
      prepare build(sort: [position: :asc])
    end

    create :create do
      accept [:name, :description_template, :position, :board_id]
      primary? true
    end

    update :update do
      accept [:name, :description_template, :position]
      primary? true
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
    define :get, action: :read, get_by: [:id]
    define :for_board, args: [:board_id]
  end
end
