defmodule Viban.Kanban.SystemHooks.ExecuteAIHook do
  @moduledoc """
  System hook that executes an AI agent on queued messages.

  This hook processes messages from the task's `message_queue`:
  1. Takes the first message from the queue
  2. Starts the AI executor with that message as the prompt
  3. After completion, checks for more messages and continues until queue is empty

  ## Message Queue Flow

  When a user sends a message in the chat:
  1. TaskChannel queues the message on `task.message_queue`
  2. TaskChannel moves task to "In Progress" column
  3. This hook triggers and processes the queued message
  4. On executor completion, TaskActor calls back to process next message

  ## Fallback Behavior

  If the message queue is empty when this hook runs (e.g., task was dragged
  to In Progress manually), it falls back to using the task's title and
  description as the prompt.
  """

  @behaviour Viban.Kanban.SystemHooks.Behaviour

  alias Viban.Executors.Executor
  alias Viban.Kanban.ExecutorSession
  alias Viban.Kanban.Task

  require Logger

  @default_executor :claude_code

  @impl true
  def id, do: "system:execute-ai"

  @impl true
  def name, do: "Execute AI"

  @impl true
  def description do
    "Processes queued messages using an AI agent (Claude Code). " <>
      "Messages are added via the chat interface."
  end

  @impl true
  def execute(task, _column, _opts) do
    worktree_path = task.worktree_path

    if is_nil(worktree_path) or not File.dir?(worktree_path) do
      Logger.warning("[ExecuteAIHook] Skipping - worktree not available for task #{task.id}")
      {:error, :worktree_not_available}
    else
      case Viban.Executors.Runner.lookup_by_task(task.id) do
        {:ok, _pid} ->
          Logger.info("[ExecuteAIHook] Executor already running for task #{task.id}, awaiting completion")

          {:await_executor, task.id}

        {:error, :not_found} ->
          process_next_message(task, worktree_path)
      end
    end
  end

  @doc """
  Process the next message in the queue. Called by TaskActor after executor completion.
  Returns :ok if there are no more messages, or starts the next executor.
  """
  def process_next_message(task_id) when is_binary(task_id) do
    case Task.get(task_id) do
      {:ok, task} ->
        worktree_path = task.worktree_path

        if is_nil(worktree_path) or not File.dir?(worktree_path) do
          Logger.warning("[ExecuteAIHook] Worktree not available for task #{task.id}")
          :ok
        else
          process_next_message(task, worktree_path)
        end

      {:error, _} ->
        Logger.error("[ExecuteAIHook] Task #{task_id} not found")
        :ok
    end
  end

  defp process_next_message(task, worktree_path) do
    message_queue = task.message_queue || []
    previous_session = get_last_session(task.id)

    case message_queue do
      [] ->
        start_without_message(task, previous_session, worktree_path)

      [first_message | _rest] ->
        start_with_queued_message(task, first_message, previous_session, worktree_path)
    end
  end

  defp get_last_session(task_id) do
    case ExecutorSession.for_task(task_id) do
      {:ok, sessions} when sessions != [] ->
        sessions
        |> Enum.filter(&(&1.status in [:completed, :failed, :stopped]))
        |> Enum.sort_by(& &1.completed_at, {:desc, DateTime})
        |> List.first()

      _ ->
        nil
    end
  end

  defp start_without_message(task, nil, worktree_path) do
    prompt = build_initial_prompt(task)
    Logger.info("[ExecuteAIHook] First session - starting with task content for #{task.id}")
    start_executor(task, prompt, @default_executor, worktree_path, [], nil)
  end

  defp start_without_message(task, previous_session, worktree_path) do
    prompt = "Continue working on this task."

    Logger.info("[ExecuteAIHook] Resuming session #{previous_session.id} for task #{task.id}")

    start_executor(task, prompt, @default_executor, worktree_path, [], previous_session.id)
  end

  defp start_with_queued_message(task, message, previous_session, worktree_path) do
    user_prompt = message.prompt || ""
    executor_type = parse_executor_type(message.executor_type)
    images = message.images || []
    resume_session_id = if previous_session, do: previous_session.id

    prompt =
      if previous_session do
        user_prompt
      else
        build_initial_prompt(task, user_prompt)
      end

    Logger.info(
      "[ExecuteAIHook] Processing message for task #{task.id}, " <>
        "executor: #{executor_type}, images: #{length(images)}, " <>
        "resume: #{resume_session_id != nil}"
    )

    case Task.pop_message(task) do
      {:ok, _updated_task} ->
        start_executor(task, prompt, executor_type, worktree_path, images, resume_session_id)

      {:error, error} ->
        Logger.error("[ExecuteAIHook] Failed to pop message: #{inspect(error)}")
        {:error, error}
    end
  end

  defp start_executor(task, prompt, executor_type, worktree_path, images, resume_session_id) do
    Task.set_in_progress(task, %{in_progress: true})

    opts = %{
      working_directory: worktree_path,
      images: images,
      resume_session_id: resume_session_id
    }

    case Executor.execute(task.id, prompt, executor_type, opts) do
      {:ok, _session} ->
        Viban.Kanban.Task.TaskServer.notify_executor_started(task.id)
        Logger.info("[ExecuteAIHook] Executor started for task #{task.id}")
        {:await_executor, task.id}

      {:error, reason} ->
        Logger.error("[ExecuteAIHook] Failed to start executor: #{inspect(reason)}")
        update_task_status(task.id, :error, "Failed to start: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp build_initial_prompt(task, user_prompt \\ nil) do
    parts = ["# Task: #{task.title}"]

    parts =
      case task.description do
        nil -> parts
        "" -> parts
        desc -> parts ++ ["## Description\n#{desc}"]
      end

    parts =
      case user_prompt do
        nil -> parts
        "" -> parts
        prompt -> parts ++ ["## Instructions\n#{prompt}"]
      end

    Enum.join(parts, "\n\n")
  end

  defp parse_executor_type(nil), do: @default_executor
  defp parse_executor_type("claude_code"), do: :claude_code
  defp parse_executor_type("gemini_cli"), do: :gemini_cli
  defp parse_executor_type(atom) when is_atom(atom), do: atom
  defp parse_executor_type(_), do: @default_executor

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
