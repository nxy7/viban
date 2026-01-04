defmodule Viban.Kanban.Repository do
  @moduledoc """
  Repository resource represents a VCS repository associated with a board.

  Repositories are used for creating git worktrees for isolated task development.
  Each task can have its own worktree created from the repository, allowing
  parallel development on multiple tasks.

  ## Supported Providers

  - `:github` - GitHub repositories
  - `:gitlab` - GitLab repositories

  ## Clone Statuses

  - `:pending` - Not yet cloned
  - `:cloning` - Clone in progress
  - `:cloned` - Successfully cloned and ready for worktree creation
  - `:error` - Clone failed (see `clone_error` for details)

  ## Uniqueness

  Each repository can only be associated with a board once (per provider).
  The identity is enforced by `[:board_id, :provider, :provider_repo_id]`.

  ## Actions

  - `create` - Associate a new repository with a board
  - `update` - Update repository metadata
  - `set_cloned` - Mark repository as successfully cloned
  - `set_clone_error` - Record clone failure
  - `set_cloning` - Mark repository as currently being cloned
  - `reset_clone_status` - Reset to pending state for retry
  - `for_board` - List all repositories for a specific board
  - `cloned` - List all successfully cloned repositories
  - `list_branches` - List branches for a task's repository
  """

  use Ash.Resource,
    domain: Viban.Kanban,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshTypescript.Resource]

  alias __MODULE__.{Actions, Changes}

  typescript do
    type_name("Repository")
  end

  postgres do
    table "repositories"
    repo Viban.Repo
  end

  attributes do
    uuid_primary_key :id

    # ===================
    # Provider Information
    # ===================

    attribute :provider, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:github, :gitlab, :local]
      default :local
      description "VCS provider (:local for local filesystem repos)"
    end

    attribute :provider_repo_id, :string do
      public? true
      description "Repository ID from the VCS provider (not used for :local)"
    end

    # ===================
    # Repository Identification
    # ===================

    attribute :name, :string do
      allow_nil? false
      public? true
      description "Repository name"
    end

    attribute :full_name, :string do
      public? true
      description "Full name (owner/repo format, computed from name for local repos)"
    end

    # ===================
    # URLs
    # ===================

    attribute :clone_url, :string do
      public? true
      description "HTTPS clone URL (not used for :local repos)"
    end

    attribute :html_url, :string do
      public? true
      description "Web URL for the repository"
    end

    # ===================
    # Git Configuration
    # ===================

    attribute :default_branch, :string do
      public? true
      default "main"
      description "Default branch to base worktrees on"
    end

    # ===================
    # Local Clone State
    # ===================

    attribute :local_path, :string do
      public? true
      description "Local path where the repository is cloned"
    end

    attribute :clone_status, :atom do
      public? true
      constraints one_of: [:pending, :cloning, :cloned, :error]
      default :pending
      description "Status of the local clone"
    end

    attribute :clone_error, :string do
      public? true
      description "Error message if cloning failed"
    end

    timestamps()
  end

  identities do
    # Prevent duplicate repository associations per board (for GitHub/GitLab)
    identity :unique_repo_per_board, [:board_id, :provider, :provider_repo_id] do
      message "This repository is already associated with this board"
      nils_distinct? true
    end

    # Prevent duplicate local repositories per board (by local_path)
    identity :unique_local_path_per_board, [:board_id, :local_path] do
      message "This local path is already configured for this board"
      nils_distinct? true
    end
  end

  relationships do
    belongs_to :board, Viban.Kanban.Board do
      allow_nil? false
      public? true
      attribute_writable? true
      description "The board this repository is associated with"
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
      change Changes.AutoCloneLocalRepo
    end

    update :update do
      accept [:name, :default_branch, :local_path, :clone_status, :clone_error, :full_name]
      primary? true
      require_atomic? false

      change Changes.SyncFullNameOnUpdate
    end

    update :set_cloned do
      accept [:local_path]
      description "Mark repository as successfully cloned"
      change set_attribute(:clone_status, :cloned)
      change set_attribute(:clone_error, nil)
    end

    update :set_clone_error do
      accept [:clone_error]
      description "Mark repository clone as failed"
      change set_attribute(:clone_status, :error)
    end

    update :set_cloning do
      description "Mark repository as currently being cloned"
      change set_attribute(:clone_status, :cloning)
      change set_attribute(:clone_error, nil)
    end

    update :reset_clone_status do
      description "Reset clone status to pending (e.g., for retry)"
      change set_attribute(:clone_status, :pending)
      change set_attribute(:clone_error, nil)
      change set_attribute(:local_path, nil)
    end

    read :for_board do
      argument :board_id, :uuid, allow_nil?: false
      filter expr(board_id == ^arg(:board_id))
    end

    read :cloned do
      filter expr(clone_status == :cloned)
    end

    action :list_branches, {:array, :map} do
      description "List available branches for a task's repository"

      argument :task_id, :uuid do
        allow_nil? false
        description "ID of the task to get branches for"
      end

      run Actions.ListBranches
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :destroy
    define :set_cloned
    define :set_clone_error, args: [:clone_error]
    define :set_cloning
    define :reset_clone_status
    define :for_board, args: [:board_id]
    define :cloned
    define :get, action: :read, get_by: [:id]
    define :list_branches, args: [:task_id]
  end
end
