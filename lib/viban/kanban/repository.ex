defmodule Viban.Kanban.Repository do
  @moduledoc """
  Repository resource represents a VCS repository linked to a board.

  The `local_path` should point to an existing git repository on the filesystem.
  Worktrees will be created from this repository using `origin/<default_branch>`.
  """

  use Ash.Resource,
    domain: Viban.Kanban,
    data_layer: AshSqlite.DataLayer

  alias Viban.Kanban.Repository.Actions
  alias Viban.Kanban.Repository.Changes

  sqlite do
    table "repositories"
    repo Viban.RepoSqlite
  end

  attributes do
    uuid_primary_key :id

    attribute :provider, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:github, :gitlab, :local]
      default :local
    end

    attribute :provider_repo_id, :string do
      public? true
    end

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :full_name, :string do
      public? true
    end

    attribute :clone_url, :string do
      public? true
    end

    attribute :html_url, :string do
      public? true
    end

    attribute :default_branch, :string do
      public? true
      default "main"
    end

    attribute :local_path, :string do
      public? true
    end

    timestamps()
  end

  identities do
    identity :unique_repo_per_board, [:board_id, :provider, :provider_repo_id] do
      nils_distinct? true
    end

    identity :unique_local_path_per_board, [:board_id, :local_path] do
      nils_distinct? true
    end
  end

  relationships do
    belongs_to :board, Viban.Kanban.Board do
      allow_nil? false
      public? true
      attribute_writable? true
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [
        :provider,
        :provider_repo_id,
        :full_name,
        :clone_url,
        :html_url,
        :name,
        :default_branch,
        :board_id,
        :local_path
      ]

      primary? true

      change Changes.SetFullNameFromName
    end

    update :update do
      accept [:name, :default_branch, :local_path, :full_name]
      primary? true
      require_atomic? false

      change Changes.SyncFullNameOnUpdate
    end

    read :for_board do
      argument :board_id, :uuid, allow_nil?: false
      filter expr(board_id == ^arg(:board_id))
    end

    action :list_branches, {:array, :map} do
      argument :task_id, :uuid do
        allow_nil? false
      end

      run Actions.ListBranches
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :destroy
    define :for_board, args: [:board_id]
    define :get, action: :read, get_by: [:id]
    define :list_branches, args: [:task_id]
  end
end
