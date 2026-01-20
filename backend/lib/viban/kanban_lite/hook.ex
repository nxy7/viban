defmodule Viban.KanbanLite.Hook do
  @moduledoc """
  Hook resource represents reusable automation (SQLite version).
  """

  use Ash.Resource,
    domain: Viban.KanbanLite,
    data_layer: AshSqlite.DataLayer

  alias Viban.KanbanLite.Hook.Validations

  sqlite do
    table "hooks"
    repo Viban.RepoSqlite
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 255
    end

    attribute :hook_kind, :atom do
      public? true
      constraints one_of: [:script, :agent]
      default :script
      allow_nil? false
    end

    attribute :command, :string do
      public? true
    end

    attribute :agent_prompt, :string do
      public? true
    end

    attribute :agent_executor, :atom do
      public? true
      constraints one_of: [:claude_code, :gemini_cli, :codex, :opencode, :cursor_agent]
      default :claude_code
    end

    attribute :agent_auto_approve, :boolean do
      public? true
      default false
    end

    attribute :default_execute_once, :boolean do
      public? true
      default false
    end

    attribute :default_transparent, :boolean do
      public? true
      default false
    end

    timestamps()
  end

  identities do
    identity :unique_name_per_board, [:board_id, :name]
  end

  relationships do
    belongs_to :board, Viban.KanbanLite.Board do
      allow_nil? false
      public? true
      attribute_writable? true
    end

    has_many :column_hooks, Viban.KanbanLite.ColumnHook do
      public? true
    end
  end

  actions do
    defaults [:read]

    read :for_board do
      argument :board_id, :uuid, allow_nil?: false
      filter expr(board_id == ^arg(:board_id))
      prepare build(sort: [name: :asc])
    end

    destroy :destroy do
      primary? true
      change cascade_destroy(:column_hooks)
    end

    create :create_script_hook do
      accept [:name, :command, :board_id, :default_execute_once, :default_transparent]
      primary? true
      change set_attribute(:hook_kind, :script)
      validate Validations.RequireCommand
    end

    create :create_agent_hook do
      accept [
        :name,
        :agent_prompt,
        :agent_executor,
        :agent_auto_approve,
        :board_id,
        :default_execute_once,
        :default_transparent
      ]

      change set_attribute(:hook_kind, :agent)
      validate Validations.RequireAgentPrompt
    end

    create :create do
      accept [:name, :command, :board_id, :default_execute_once, :default_transparent]
      change set_attribute(:hook_kind, :script)
      validate Validations.RequireCommand
    end

    update :update do
      accept [
        :name,
        :command,
        :agent_prompt,
        :agent_executor,
        :agent_auto_approve,
        :default_execute_once,
        :default_transparent
      ]

      primary? true
      require_atomic? false
      validate Validations.ValidateHookKindAttributes
    end
  end

  code_interface do
    define :create
    define :create_script_hook
    define :create_agent_hook
    define :read
    define :update
    define :destroy
    define :get, action: :read, get_by: [:id]
    define :for_board, args: [:board_id]
  end
end
