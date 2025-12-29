defmodule Viban.LLM.TaskRefiner do
  @moduledoc """
  Uses Claude Code CLI to refine task descriptions into high-quality, actionable prompts.

  This module transforms simple task titles/descriptions into well-structured
  prompts that follow best practices for LLM-assisted development. The refinement
  process adds:

  - Clear objectives and expected outcomes
  - Acceptance criteria for completion
  - Appropriate scope boundaries
  - Technical context where applicable

  ## Usage

      {:ok, refined} = TaskRefiner.refine("Fix login bug")
      {:ok, refined} = TaskRefiner.refine("Add dark mode", "Users want a dark theme")

  ## Model Selection

  Uses the "haiku" model by default for fast, cost-effective refinements.
  """

  alias Viban.LLM.ClaudeRunner

  require Logger

  # ---------------------------------------------------------------------------
  # Constants
  # ---------------------------------------------------------------------------

  @log_prefix "[TaskRefiner]"

  @default_model "haiku"

  @default_timeout_ms 60_000

  @refinement_instruction """
  Do not use any tools. Just reply with text only.
  Refine this task into a high-quality, actionable prompt with clear objectives, acceptance criteria, and scope.
  Keep it concise.
  """

  # ---------------------------------------------------------------------------
  # Type Definitions
  # ---------------------------------------------------------------------------

  @type refine_result :: {:ok, String.t()} | {:error, String.t()}

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Refines a task title and optional description into a high-quality prompt.

  Uses Claude Code CLI (haiku model) to transform a brief task description
  into a well-structured, actionable prompt with clear objectives and
  acceptance criteria.

  ## Parameters

  - `title` - The task title (required)
  - `description` - Optional additional context or details

  ## Returns

  - `{:ok, refined_text}` - The refined, structured prompt
  - `{:error, reason}` - If the refinement failed

  ## Examples

      # Simple title only
      {:ok, refined} = TaskRefiner.refine("Fix login bug")

      # Title with description
      {:ok, refined} = TaskRefiner.refine(
        "Add dark mode",
        "Users have requested a dark theme for better readability at night"
      )

      # Empty description is treated as nil
      {:ok, refined} = TaskRefiner.refine("Update deps", "")
  """
  @spec refine(String.t(), String.t() | nil) :: refine_result()
  def refine(title, description \\ nil) do
    Logger.debug("#{@log_prefix} Refining task: #{title}")

    prompt = build_prompt(title, description)

    case ClaudeRunner.run(prompt, model: @default_model, timeout_ms: @default_timeout_ms) do
      {:ok, refined} ->
        Logger.debug("#{@log_prefix} Successfully refined task")
        {:ok, refined}

      {:error, reason} ->
        Logger.warning("#{@log_prefix} Failed to refine task: #{reason}")
        {:error, reason}
    end
  end

  # ---------------------------------------------------------------------------
  # Private Functions
  # ---------------------------------------------------------------------------

  @spec build_prompt(String.t(), String.t() | nil) :: String.t()
  defp build_prompt(title, description) when description in ["", nil] do
    """
    #{@refinement_instruction}

    Task: #{title}
    """
  end

  defp build_prompt(title, description) do
    """
    #{@refinement_instruction}

    Task: #{title}
    Details: #{description}
    """
  end
end
