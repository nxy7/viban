defmodule Viban.LLM.SubtaskGenerationService do
  @moduledoc """
  Service for AI-powered subtask generation from parent task descriptions.

  Uses Claude Code CLI to analyze a parent task and break it down into
  smaller, actionable subtasks. The service sends the parent task's title
  and description to Claude, which returns a structured JSON array of subtasks.

  ## Features

  - Automatic task breakdown into 3-8 subtasks
  - Priority assignment (low, medium, high)
  - Logical dependency ordering
  - Clear, actionable subtask descriptions

  ## Usage

      parent_task = %{id: "uuid", title: "Add auth", description: "..."}
      {:ok, subtask_ids} = SubtaskGenerationService.generate_subtasks(parent_task)

  ## Options

  - `:timeout_ms` - Timeout for Claude CLI execution (default: 120,000ms)
  """

  require Logger

  alias Viban.Kanban.Task, as: KanbanTask
  alias Viban.LLM.ClaudeRunner

  # ---------------------------------------------------------------------------
  # Constants
  # ---------------------------------------------------------------------------

  @log_prefix "[SubtaskGenerationService]"

  @default_timeout_ms 120_000

  @default_model "sonnet"

  @min_subtasks 1

  @system_prompt """
  You are a task breakdown specialist. Your job is to analyze a parent task and break it down
  into smaller, actionable subtasks.

  Guidelines for subtask generation:
  1. Each subtask should be independently completable
  2. Subtasks should be atomic - focused on one specific thing
  3. Order subtasks logically (dependencies should come first)
  4. Include 3-8 subtasks typically (fewer for simple tasks, more for complex)
  5. Each subtask needs a clear, actionable title
  6. Subtask descriptions should include:
     - What needs to be done
     - Any relevant technical details
     - Success criteria

  IMPORTANT: You must respond with a JSON array of subtasks. Do NOT use any tools.
  Format your response as:
  [
    {"title": "Subtask title 1", "description": "What to do", "priority": "medium"},
    {"title": "Subtask title 2", "description": "What to do", "priority": "high"}
  ]

  Priority must be one of: "low", "medium", "high"
  """

  # ---------------------------------------------------------------------------
  # Type Definitions
  # ---------------------------------------------------------------------------

  @type priority :: :low | :medium | :high

  @type subtask_data :: %{
          String.t() => String.t()
        }

  @type generate_option :: {:timeout_ms, pos_integer()}

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Generate subtasks for a parent task.

  Analyzes the parent task's title and description using Claude AI
  and creates subtasks in the database.

  ## Parameters

  - `parent_task` - The parent task struct with `:id`, `:title`, and optionally `:description`
  - `opts` - Keyword list of options

  ## Options

  - `:timeout_ms` - Timeout for Claude CLI execution (default: #{@default_timeout_ms}ms)

  ## Returns

  - `{:ok, subtask_ids}` - List of created subtask UUIDs
  - `{:error, reason}` - If generation or parsing failed

  ## Examples

      {:ok, ids} = SubtaskGenerationService.generate_subtasks(parent_task)
      {:ok, ids} = SubtaskGenerationService.generate_subtasks(parent_task, timeout_ms: 180_000)
  """
  @spec generate_subtasks(struct(), [generate_option()]) ::
          {:ok, [Ecto.UUID.t()]} | {:error, term()}
  def generate_subtasks(parent_task, opts \\ []) do
    Logger.info("#{@log_prefix} Generating subtasks for task #{parent_task.id}")

    timeout_ms = Keyword.get(opts, :timeout_ms, @default_timeout_ms)
    prompt = build_prompt(parent_task)

    case ClaudeRunner.run(prompt, model: @default_model, timeout_ms: timeout_ms) do
      {:ok, output} ->
        handle_claude_output(output, parent_task.id)

      {:error, reason} ->
        Logger.error("#{@log_prefix} Claude CLI failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # ---------------------------------------------------------------------------
  # Private Functions - Prompt Building
  # ---------------------------------------------------------------------------

  defp build_prompt(task) do
    description = task.description || "(No description provided - infer from title)"

    """
    #{@system_prompt}

    Please break down this parent task into subtasks:

    **Task Title**: #{task.title}
    **Task Description**:
    #{description}

    Analyze the task and respond with a JSON array of subtasks.
    """
  end

  # ---------------------------------------------------------------------------
  # Private Functions - Response Handling
  # ---------------------------------------------------------------------------

  defp handle_claude_output(output, parent_task_id) do
    case parse_subtasks(output) do
      {:ok, subtasks_data} ->
        create_subtasks(parent_task_id, subtasks_data)

      {:error, reason} ->
        Logger.error("#{@log_prefix} Failed to parse subtasks: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp parse_subtasks(output) do
    case extract_json_array(output) do
      {:ok, json_str} ->
        parse_json_subtasks(json_str)

      {:error, _} = error ->
        error
    end
  end

  defp extract_json_array(output) do
    case Regex.run(~r/\[[\s\S]*?\]/m, output) do
      [json_str] ->
        {:ok, json_str}

      nil ->
        {:error, :no_json_array_found}
    end
  end

  defp parse_json_subtasks(json_str) do
    case Jason.decode(json_str) do
      {:ok, subtasks} when is_list(subtasks) ->
        validate_subtasks(subtasks)

      {:ok, _} ->
        {:error, :response_not_array}

      {:error, reason} ->
        {:error, {:json_parse_error, reason}}
    end
  end

  defp validate_subtasks(subtasks) do
    valid_subtasks =
      Enum.filter(subtasks, fn subtask ->
        is_map(subtask) && Map.has_key?(subtask, "title")
      end)

    if length(valid_subtasks) >= @min_subtasks do
      {:ok, valid_subtasks}
    else
      {:error, :no_valid_subtasks}
    end
  end

  # ---------------------------------------------------------------------------
  # Private Functions - Subtask Creation
  # ---------------------------------------------------------------------------

  defp create_subtasks(parent_task_id, subtasks_data) do
    Logger.info(
      "#{@log_prefix} Creating #{length(subtasks_data)} subtasks for parent #{parent_task_id}"
    )

    subtask_ids =
      subtasks_data
      |> Enum.map(&create_single_subtask(parent_task_id, &1))
      |> Enum.reject(&is_nil/1)

    if length(subtask_ids) >= @min_subtasks do
      {:ok, subtask_ids}
    else
      {:error, :failed_to_create_subtasks}
    end
  end

  defp create_single_subtask(parent_task_id, subtask_data) do
    title = Map.get(subtask_data, "title", "Untitled subtask")
    description = Map.get(subtask_data, "description")
    priority = parse_priority(Map.get(subtask_data, "priority", "medium"))

    case KanbanTask.create_subtask(
           %{
             title: title,
             description: description,
             priority: priority
           },
           parent_task_id
         ) do
      {:ok, subtask} ->
        Logger.info("#{@log_prefix} Created subtask: #{subtask.id} - #{title}")
        subtask.id

      {:error, error} ->
        Logger.error("#{@log_prefix} Failed to create subtask '#{title}': #{inspect(error)}")
        nil
    end
  end

  @spec parse_priority(String.t()) :: priority()
  defp parse_priority("low"), do: :low
  defp parse_priority("high"), do: :high
  defp parse_priority(_), do: :medium
end
