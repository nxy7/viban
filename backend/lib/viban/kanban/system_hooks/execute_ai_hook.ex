defmodule Viban.Kanban.SystemHooks.ExecuteAIHook do
  @moduledoc """
  System hook that executes an AI agent (Claude Code by default) on the task.

  This hook runs the configured AI executor with the task's title and description
  as the prompt. It's the default hook for the "In Progress" column.

  ## Behavior

  When a task enters a column with this hook:
  1. Builds a prompt from the task's title and description
  2. Starts the AI executor (claude_code by default)
  3. Returns immediately (non-blocking)

  The executor completion is handled by the Runner which broadcasts completion
  via PubSub. The TaskActor listens for this and handles auto-move to "To Review".

  ## Usage

  This hook is typically attached to the "In Progress" column as the default
  way to execute AI work on tasks.
  """

  @behaviour Viban.Kanban.SystemHooks.Behaviour

  require Logger

  alias Viban.Kanban.Task
  alias Viban.Executors.Executor

  @default_executor :claude_code

  @impl true
  def id, do: "system:execute-ai"

  @impl true
  def name, do: "Execute AI"

  @impl true
  def description do
    "Runs an AI agent (Claude Code) to work on the task using its title and description as the prompt"
  end

  @impl true
  def execute(task, _column, _opts) do
    worktree_path = task.worktree_path

    if is_nil(worktree_path) or not File.dir?(worktree_path) do
      Logger.warning("[ExecuteAIHook] Skipping - worktree not available for task #{task.id}")
      {:error, :worktree_not_available}
    else
      # Check if executor is already running for this task
      # This can happen when user sends a message which starts executor directly
      case Viban.Executors.Runner.lookup_by_task(task.id) do
        {:ok, _pid} ->
          Logger.info("[ExecuteAIHook] Executor already running for task #{task.id}, awaiting its completion")
          # Return :await_executor to keep hook "running" until executor completes
          # TaskActor will handle updating the hook status when executor finishes
          {:await_executor, task.id}

        {:error, :not_found} ->
          # No executor running - start one
          prompt = build_prompt(task)

          Logger.info("[ExecuteAIHook] Starting AI execution for task #{task.id}")

          # Mark task as in_progress
          Task.set_in_progress(task, %{in_progress: true})

          case Executor.execute(task.id, prompt, @default_executor, worktree_path) do
            {:ok, _session} ->
              # Notify TaskActor so it can track completion
              Viban.Kanban.Actors.TaskActor.notify_executor_started(task.id)

              Logger.info("[ExecuteAIHook] Executor started for task #{task.id}")
              # Return :await_executor to tell hook system to keep this hook "running"
              # until the executor completes (TaskActor will handle the completion)
              {:await_executor, task.id}

            {:error, reason} ->
              Logger.error("[ExecuteAIHook] Failed to start executor: #{inspect(reason)}")
              update_task_status(task.id, :error, "Failed to start: #{inspect(reason)}")
              {:error, reason}
          end
      end
    end
  end

  defp build_prompt(task) do
    case task.description do
      nil -> task.title
      "" -> task.title
      desc -> "#{task.title}\n\n#{desc}"
    end
  end

  defp update_task_status(task_id, status, message) do
    case Task.get(task_id) do
      {:ok, task} ->
        Task.update_agent_status(task, %{
          agent_status: status,
          agent_status_message: message
        })

        Task.set_in_progress(task, %{in_progress: false})

      _ ->
        :ok
    end
  end
end
