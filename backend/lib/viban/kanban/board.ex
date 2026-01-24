defmodule Viban.Kanban.Board do
  @moduledoc """
  Board resource representing a Kanban board (SQLite version).

  Each board belongs to a user and contains columns, hooks, repositories, and templates.
  When a board is created, default columns and task templates are automatically generated.
  """

  use Ash.Resource,
    domain: Viban.Kanban,
    data_layer: AshSqlite.DataLayer

  alias Viban.Kanban.Board.Actions
  alias Viban.Kanban.Board.Changes

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
    has_many :columns, Viban.Kanban.Column do
      public? true
      sort position: :asc
    end

    has_many :hooks, Viban.Kanban.Hook do
      public? true
    end

    has_many :repositories, Viban.Kanban.Repository do
      public? true
    end

    has_many :task_templates, Viban.Kanban.TaskTemplate do
      public? true
      sort position: :asc
    end

    has_many :periodical_tasks, Viban.Kanban.PeriodicalTask do
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

    action :create_with_repository, :struct do
      constraints instance_of: __MODULE__

      argument :name, :string do
        allow_nil? false
        constraints min_length: 1, max_length: 255
      end

      argument :description, :string do
        allow_nil? true
        constraints max_length: 2000
      end

      argument :user_id, :uuid do
        allow_nil? false
      end

      argument :repo, :map do
        allow_nil? false
      end

      run Actions.CreateWithRepository
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
    define :create_with_repository, args: [:name, :description, :user_id, :repo]
  end
end
