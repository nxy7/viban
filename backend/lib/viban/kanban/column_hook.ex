defmodule Viban.Kanban.ColumnHook do
  @moduledoc """
  Join resource that connects Columns to Hooks.

  All hooks are `on_entry` hooks - they run when a task enters the column.

  ## Hook IDs

  The `hook_id` can be either:
  - A UUID referencing a `Viban.Kanban.Hook` in the database
  - A string like "system:execute-ai" for built-in system hooks

  ## Execute Once

  When `execute_once` is true, the hook will only run once per task, even
  if the task re-enters the column. Execution is tracked in the task's
  `executed_hooks` field.

  ## Position

  Hooks on the same column are executed in order of their `position` value (ascending).
  Users can reorder hooks via drag-and-drop in the UI.
  """

  use Ash.Resource,
    domain: Viban.Kanban,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshTypescript.Resource]

  alias Viban.Kanban.ColumnHook.Validations
  alias Viban.Kanban.SystemHooks.Registry

  typescript do
    type_name("ColumnHook")
  end

  postgres do
    table "column_hooks"
    repo Viban.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :hook_id, :string do
      allow_nil? false
      public? true
      description "Hook ID - UUID for custom hooks or 'system:*' for built-in hooks"
    end

    attribute :hook_type, :atom do
      public? true
      constraints one_of: [:on_entry]
      allow_nil? false
      default :on_entry
      description "Hook trigger type (always on_entry)"
    end

    attribute :position, :integer do
      public? true
      default 0
      description "Execution order within the same hook_type (ascending)"
    end

    attribute :execute_once, :boolean do
      public? true
      default false
      description "If true, only execute once per task lifetime"
    end

    attribute :hook_settings, :map do
      public? true
      default %{}
      description "Hook-specific settings (e.g., sound selection for play-sound hook)"
    end

    attribute :transparent, :boolean do
      public? true
      default false

      description "If true, hook runs even when task is in error state and doesn't change task status"
    end

    attribute :removable, :boolean do
      public? true
      default true

      description "If false, this hook cannot be removed from the column (e.g., core AI execution hook)"
    end

    timestamps()
  end

  identities do
    # Prevent duplicate hook assignments on the same column
    identity :unique_hook_per_column, [:column_id, :hook_id] do
      message "This hook is already attached to this column"
    end
  end

  relationships do
    belongs_to :column, Viban.Kanban.Column do
      allow_nil? false
      public? true
      attribute_writable? true
      description "The column this hook is attached to"
    end

    # Note: No direct relationship to Hook since hook_id might be a system hook
  end

  actions do
    defaults [:read]

    # Custom destroy that prevents deleting non-removable hooks
    destroy :destroy do
      primary? true
      require_atomic? false

      validate fn changeset, _ ->
        column_hook = changeset.data

        if column_hook.removable == false do
          {:error, field: :removable, message: "This hook cannot be removed"}
        else
          :ok
        end
      end
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
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :destroy
    define :get, action: :read, get_by: [:id]
  end

  # ===================
  # Public API
  # ===================

  @doc """
  Check if a hook_id is valid (either a system hook or a valid UUID).

  ## Examples

      iex> ColumnHook.valid_hook_id?("system:refine-prompt")
      true

      iex> ColumnHook.valid_hook_id?("550e8400-e29b-41d4-a716-446655440000")
      true

      iex> ColumnHook.valid_hook_id?("invalid")
      false
  """
  @spec valid_hook_id?(term()) :: boolean()
  def valid_hook_id?(hook_id) when is_binary(hook_id) do
    cond do
      Registry.system_hook?(hook_id) ->
        match?({:ok, _}, Registry.get(hook_id))

      true ->
        match?({:ok, _}, Ecto.UUID.cast(hook_id))
    end
  end

  def valid_hook_id?(_), do: false

  @doc """
  Check if this is a system hook ID (starts with "system:").
  """
  @spec system_hook?(String.t()) :: boolean()
  def system_hook?(hook_id) when is_binary(hook_id) do
    Registry.system_hook?(hook_id)
  end

  def system_hook?(_), do: false
end
