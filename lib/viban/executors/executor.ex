defmodule Viban.Executors.Executor do
  @moduledoc """
  Ash Resource representing an executor (CLI tool or API-based AI agent).

  This resource uses the Simple data layer (no persistence) as executors
  are discovered at runtime from the system (checking for installed CLIs)
  and the executor registry.

  ## Executor Types

  Executors can be various AI-powered development tools:
  - `:claude_code` - Anthropic's Claude Code CLI
  - `:gemini_cli` - Google's Gemini CLI
  - `:aider` - Aider AI pair programming tool

  ## Generic Actions

  This resource demonstrates Ash's generic action capabilities:
  - `:list_available` - Returns all executors available on the system
  - `:list_all` - Returns all registered executors (available or not)
  - `:execute` - Starts an executor for a given task and prompt
  - `:check_available` - Checks if a specific executor type is available

  ## Examples

      # List available executors
      Viban.Executors.Executor.list_available!()
      #=> [%{name: "Claude Code", type: :claude_code, available: true, ...}]

      # Check if an executor is available
      Viban.Executors.Executor.check_available!(:claude_code)
      #=> true

      # Start an executor
      Viban.Executors.Executor.execute!(%{
        task_id: "550e8400-e29b-41d4-a716-446655440000",
        prompt: "Fix the bug in auth.ex",
        executor_type: :claude_code,
        working_directory: "/path/to/worktree"
      })

  ## Image Attachments

  Executors support image attachments for visual context:

      Viban.Executors.Executor.execute!(%{
        task_id: "uuid",
        prompt: "Fix this UI bug shown in the screenshot",
        executor_type: :claude_code,
        working_directory: "/path/to/worktree",
        images: [
          %{name: "screenshot.png", data: "base64...", mimeType: "image/png"}
        ]
      })
  """

  use Ash.Resource,
    domain: Viban.Executors,
    data_layer: Ash.DataLayer.Simple

  alias Viban.Executors.Registry

  # ---------------------------------------------------------------------------
  # Type Definitions
  # ---------------------------------------------------------------------------

  @type executor_type :: :claude_code | :gemini_cli | :aider | atom()
  @type capability :: :code_generation | :code_review | :refactoring | :testing | atom()

  @type executor_info :: %{
          name: String.t(),
          type: executor_type(),
          available: boolean(),
          capabilities: [capability()]
        }

  @type image_attachment :: %{
          name: String.t(),
          data: String.t(),
          mimeType: String.t()
        }

  @type execute_result :: %{
          pid: pid(),
          session_id: Ecto.UUID.t(),
          task_id: Ecto.UUID.t()
        }

  # ---------------------------------------------------------------------------
  # Resource Configuration
  # ---------------------------------------------------------------------------

  resource do
    require_primary_key? false
  end

  # ---------------------------------------------------------------------------
  # Attributes
  # ---------------------------------------------------------------------------

  attributes do
    attribute :name, :string do
      allow_nil? false
      public? true
      description "Human-readable name of the executor"
    end

    attribute :type, :atom do
      allow_nil? false
      public? true
      description "Unique identifier for this executor type"
    end

    attribute :available, :boolean do
      allow_nil? false
      public? true
      description "Whether this executor is currently available on the system"
    end

    attribute :capabilities, {:array, :atom} do
      public? true
      description "List of capabilities this executor supports"
    end
  end

  # ---------------------------------------------------------------------------
  # Actions
  # ---------------------------------------------------------------------------

  actions do
    action :list_available, {:array, :map} do
      description "List all available executors on the system"

      run fn _input, _context ->
        {:ok, Registry.list_available()}
      end
    end

    action :list_all, {:array, :map} do
      description "List all registered executors (available or not)"

      run fn _input, _context ->
        {:ok, Registry.list_all()}
      end
    end

    action :execute, :map do
      description "Start an executor for a task"

      argument :task_id, :uuid do
        allow_nil? false
        description "The task ID to associate with this executor session"
      end

      argument :prompt, :string do
        allow_nil? false
        description "The prompt/instruction for the executor"
      end

      argument :executor_type, :atom do
        allow_nil? false
        description "The type of executor to use (e.g., :claude_code, :gemini_cli)"
      end

      argument :working_directory, :string do
        description "Working directory for the executor (typically a git worktree)"
      end

      argument :images, {:array, :map} do
        default []
        description "List of image attachments with name, data (base64), and mimeType"
      end

      argument :continue_session, :boolean do
        default false
        description "Whether to continue the most recent conversation in this working directory"
      end

      run Viban.Executors.Actions.Execute
    end

    action :check_available, :boolean do
      description "Check if an executor type is available"

      argument :executor_type, :atom do
        allow_nil? false
        description "The executor type to check"
      end

      run fn input, _context ->
        {:ok, Registry.available?(input.arguments.executor_type)}
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Code Interface
  # ---------------------------------------------------------------------------

  code_interface do
    define :list_available
    define :list_all
    define :execute, args: [:task_id, :prompt, :executor_type]
    define :check_available, args: [:executor_type]
  end
end
