defmodule Viban.KanbanLite.Board do
  @moduledoc """
  Board resource representing a Kanban board (SQLite version).

  Each board belongs to a user and contains columns, hooks, repositories, and templates.
  When a board is created, default columns and task templates are automatically generated.
  """

  use Ash.Resource,
    domain: Viban.KanbanLite,
    data_layer: AshSqlite.DataLayer

  alias Viban.KanbanLite.Board.Changes

  sqlite do
    table "boards"
    repo Viban.RepoSqlite
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 255
    end

    attribute :description, :string do
      public? true
      constraints max_length: 2000
    end

    attribute :user_id, :uuid do
      allow_nil? false
      public? true
    end

    timestamps()
  end

  identities do
    identity :unique_name_per_user, [:user_id, :name]
  end

  relationships do
    has_many :columns, Viban.KanbanLite.Column do
      public? true
      sort position: :asc
    end

    has_many :hooks, Viban.KanbanLite.Hook do
      public? true
    end

    has_many :repositories, Viban.KanbanLite.Repository do
      public? true
    end

    has_many :task_templates, Viban.KanbanLite.TaskTemplate do
      public? true
      sort position: :asc
    end

    has_many :periodical_tasks, Viban.KanbanLite.PeriodicalTask do
      public? true
    end
  end

  actions do
    defaults [:read]

    create :create do
      accept [:name, :description, :user_id]
      primary? true

      change Changes.CreateDefaultColumns
      change Changes.CreateDefaultTemplates
    end

    update :update do
      accept [:name, :description]
      primary? true
    end

    destroy :destroy do
      primary? true

      change cascade_destroy(:columns)
      change cascade_destroy(:hooks)
      change cascade_destroy(:repositories)
      change cascade_destroy(:task_templates)
      change cascade_destroy(:periodical_tasks)
    end

    read :for_user do
      argument :user_id, :uuid, allow_nil?: false
      filter expr(user_id == ^arg(:user_id))
      prepare build(sort: [inserted_at: :desc])
    end

    read :list_all do
      prepare build(sort: [inserted_at: :desc])
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :destroy
    define :for_user, args: [:user_id]
    define :list_all
    define :get, action: :read, get_by: [:id]
  end
end
