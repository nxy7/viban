defmodule Viban.Kanban.Hook do
  @moduledoc """
  Hook resource represents reusable automation that runs when tasks enter columns.

  ## Hook Types

  - **Script hooks**: Execute shell commands with shebang support
  - **Agent hooks**: Run AI agents with custom prompts

  ## Executors

  Agent hooks support multiple executor backends:
  - `:claude_code` - Anthropic Claude with code execution
  - `:gemini_cli` - Google Gemini CLI
  - `:codex` - OpenAI Codex
  - `:opencode` - OpenCode agent
  - `:cursor_agent` - Cursor AI agent

  All hooks execute in the task's git worktree directory.

  ## Validation

  Script hooks require a `command`, agent hooks require an `agent_prompt`.
  These validations are enforced at the action level.
  """

  use Ash.Resource,
    domain: Viban.Kanban,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshTypescript.Resource]

  alias Viban.Kanban.Hook.Validations

  typescript do
    type_name("Hook")
  end

  postgres do
    table "hooks"
    repo Viban.Repo
  end

  attributes do
    uuid_primary_key :id

    # ===================
    # Common Attributes
    # ===================

    attribute :name, :string do
      allow_nil? false
      public? true
      description "Human-readable name for this hook"
    end

    attribute :hook_kind, :atom do
      public? true
      constraints one_of: [:script, :agent]
      default :script
      allow_nil? false
      description "Hook type: :script for shell commands, :agent for AI agents"
    end

    # ===================
    # Script Hook Attributes
    # ===================

    attribute :command, :string do
      public? true
      description "Shell command or script path (required for script hooks)"
    end

    # ===================
    # Agent Hook Attributes
    # ===================

    attribute :agent_prompt, :string do
      public? true
      description "System prompt for agent hooks (required for agent hooks)"
    end

    attribute :agent_executor, :atom do
      public? true
      constraints one_of: [:claude_code, :gemini_cli, :codex, :opencode, :cursor_agent]
      default :claude_code
      description "Executor backend for agent hooks"
    end

    attribute :agent_auto_approve, :boolean do
      public? true
      default false
      description "Whether agent can auto-approve tool calls"
    end

    # ===================
    # Default Settings for ColumnHook
    # These are applied when the hook is added to a column
    # ===================

    attribute :default_execute_once, :boolean do
      public? true
      default false
      description "Default value for execute_once when adding this hook to a column"
    end

    attribute :default_transparent, :boolean do
      public? true
      default false
      description "Default value for transparent when adding this hook to a column"
    end

    timestamps()
  end

  identities do
    identity :unique_name_per_board, [:board_id, :name] do
      message "A hook with this name already exists for this board"
    end
  end

  relationships do
    belongs_to :board, Viban.Kanban.Board do
      allow_nil? false
      public? true
      attribute_writable? true
      description "The board this hook belongs to"
    end

    has_many :column_hooks, Viban.Kanban.ColumnHook do
      public? true
      description "Column associations for this hook"
    end
  end

  actions do
    defaults [:read]

    destroy :destroy do
      primary? true
      change cascade_destroy(:column_hooks)
    end

    create :create_script_hook do
      accept [:name, :command, :board_id, :default_execute_once, :default_transparent]
      primary? true
      description "Create a script-based hook (command required)"
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

      description "Create an AI agent hook (agent_prompt required)"
      change set_attribute(:hook_kind, :agent)
      validate Validations.RequireAgentPrompt
    end

    create :create do
      accept [:name, :command, :board_id, :default_execute_once, :default_transparent]
      description "Create a script hook (alias for create_script_hook)"
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
  end
end
