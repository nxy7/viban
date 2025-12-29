defmodule Viban.Kanban.Board do
  @moduledoc """
  Board resource representing a Kanban board.

  Each board belongs to a user and contains columns, hooks, and repositories.
  When a board is created, default columns are automatically generated.

  ## Uniqueness

  Board names must be unique per user - a user cannot have two boards with
  the same name.

  ## Default Columns

  When created, boards automatically get these columns:
  - TODO (position 0)
  - In Progress (position 1)
  - To Review (position 2)
  - Done (position 3)
  - Cancelled (position 4)

  ## Cascade Deletion

  When a board is deleted, all associated columns, hooks, and repositories
  are automatically deleted.
  """

  use Ash.Resource,
    domain: Viban.Kanban,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshTypescript.Resource]

  alias Viban.Kanban.Board.Changes

  typescript do
    type_name("Board")
  end

  postgres do
    table "boards"
    repo Viban.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 255
      description "Board name (unique per user)"
    end

    attribute :description, :string do
      public? true
      constraints max_length: 2000
      description "Optional board description"
    end

    timestamps()
  end

  identities do
    identity :unique_name_per_user, [:user_id, :name] do
      message "A board with this name already exists for this user"
    end
  end

  relationships do
    belongs_to :user, Viban.Accounts.User do
      allow_nil? false
      public? true
      attribute_writable? true
      description "The user who owns this board"
    end

    has_many :columns, Viban.Kanban.Column do
      public? true
      sort position: :asc
      description "Columns in this board, ordered by position"
    end

    has_many :hooks, Viban.Kanban.Hook do
      public? true
      description "Automation hooks defined for this board"
    end

    has_many :repositories, Viban.Kanban.Repository do
      public? true
      description "Git repositories associated with this board"
    end
  end

  actions do
    defaults [:read]

    create :create do
      description "Create a new board with default columns"

      accept [:name, :description, :user_id]
      primary? true

      change Changes.CreateDefaultColumns
    end

    update :update do
      description "Update board name or description"

      accept [:name, :description]
      primary? true
    end

    destroy :destroy do
      description "Delete board and all associated data"

      primary? true

      # Cascade delete in order of dependencies
      change cascade_destroy(:columns)
      change cascade_destroy(:hooks)
      change cascade_destroy(:repositories)
    end

    read :for_user do
      description "List all boards owned by a specific user"

      argument :user_id, :uuid do
        allow_nil? false
        description "The user's ID"
      end

      filter expr(user_id == ^arg(:user_id))
      prepare build(sort: [inserted_at: :desc])
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :destroy
    define :for_user, args: [:user_id]
    define :get, action: :read, get_by: [:id]
  end
end
