defmodule Viban.Kanban.ColumnHook do
  @moduledoc """
  Join resource that connects Columns to Hooks (SQLite version).
  """

  use Ash.Resource,
    domain: Viban.Kanban,
    data_layer: AshSqlite.DataLayer

  alias Viban.Kanban.ColumnHook.Validations
  alias Viban.Kanban.SystemHooks.Registry

  sqlite do
    table "column_hooks"
    repo Viban.RepoSqlite
  end

  attributes do
    uuid_primary_key :id

    attribute :hook_id, :string do
      allow_nil? false
      public? true
    end

    attribute :hook_type, :atom do
      public? true
      constraints one_of: [:on_entry]
      allow_nil? false
      default :on_entry
    end

    attribute :position, :integer do
      public? true
      default 0
    end

    attribute :execute_once, :boolean do
      public? true
      default false
    end

    attribute :hook_settings, :map do
      public? true
      default %{}
    end

    attribute :transparent, :boolean do
      public? true
      default false
    end

    attribute :removable, :boolean do
      public? true
      default true
    end

    timestamps()
  end

  identities do
    identity :unique_hook_per_column, [:column_id, :hook_id]
  end

  relationships do
    belongs_to :column, Viban.Kanban.Column do
      allow_nil? false
      public? true
      attribute_writable? true
    end
  end

  actions do
    defaults [:read]

    read :for_column do
      argument :column_id, :uuid, allow_nil?: false
      filter expr(column_id == ^arg(:column_id))
      prepare build(sort: [position: :asc])
    end

    destroy :destroy do
      primary? true
      require_atomic? false

      validate Validations.RequireRemovable
    end

    create :create do
      accept [
        :position,
        :column_id,
        :hook_id,
        :execute_once,
        :hook_settings,
        :transparent,
        :removable
      ]

      primary? true
      validate Validations.ValidHookId
    end

    update :update do
      accept [:position, :execute_once, :hook_settings, :transparent]
      primary? true
      require_atomic? false
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :destroy
    define :get, action: :read, get_by: [:id]
    define :for_column, args: [:column_id]
  end

  def valid_hook_id?(hook_id) when is_binary(hook_id) do
    if Registry.system_hook?(hook_id) do
      match?({:ok, _}, Registry.get(hook_id))
    else
      match?({:ok, _}, Ecto.UUID.cast(hook_id))
    end
  end

  def valid_hook_id?(_), do: false

  def system_hook?(hook_id) when is_binary(hook_id) do
    Registry.system_hook?(hook_id)
  end

  def system_hook?(_), do: false
end
