defmodule Viban.KanbanLite.Repository do
  @moduledoc """
  Repository resource represents a VCS repository (SQLite version).
  """

  use Ash.Resource,
    domain: Viban.KanbanLite,
    data_layer: AshSqlite.DataLayer

  alias Viban.KanbanLite.Repository.Actions
  alias Viban.KanbanLite.Repository.Changes

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

    attribute :clone_status, :atom do
      public? true
      constraints one_of: [:pending, :cloning, :cloned, :error]
      default :pending
    end

    attribute :clone_error, :string do
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
    belongs_to :board, Viban.KanbanLite.Board do
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
      change set_attribute(:clone_status, :cloned)
      change set_attribute(:clone_error, nil)
    end

    update :set_clone_error do
      accept [:clone_error]
      change set_attribute(:clone_status, :error)
    end

    update :set_cloning do
      change set_attribute(:clone_status, :cloning)
      change set_attribute(:clone_error, nil)
    end

    update :reset_clone_status do
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
