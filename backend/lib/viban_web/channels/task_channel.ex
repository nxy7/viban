defmodule VibanWeb.TaskChannel do
  @moduledoc """
  Phoenix Channel for task communication.

  Handles real-time communication between users and executor agents
  for a specific task. Supports:
  - Starting/stopping executors
  - Receiving executor output streams
  - Getting task/executor status
  - Message history

  ## Events

  ### Incoming (client -> server)
  - `start_executor` - Start an executor for the task
  - `stop_executor` - Stop a running executor
  - `get_status` - Get current task/executor status
  - `get_history` - Get executor session history
  - `list_executors` - List available executors

  ### Outgoing (server -> client)
  - `executor_started` - Executor has started
  - `executor_output` - Executor output (stdout/stderr)
  - `executor_completed` - Executor has finished
  - `executor_error` - Executor error occurred
  """

  use Phoenix.Channel

  alias Viban.Kanban.Task
  alias Viban.Executors.{Executor, ExecutorSession, ExecutorMessage, Registry}

  require Logger

  @impl true
  def join("task:" <> task_id, _params, socket) do
    case Task.get(task_id) do
      {:ok, task} ->
        socket =
          socket
          |> assign(:task_id, task_id)
          |> assign(:task, task)

        {:ok, %{task_id: task_id}, socket}

      {:error, _} ->
        {:error, %{reason: "task_not_found"}}
    end
  end

  # Start an executor for this task.
  # Params:
  # - `executor_type` - Atom type of executor (e.g., "claude_code", "gemini_cli")
  # - `prompt` - The prompt/instruction for the executor
  # - `working_directory` - Optional working directory (defaults to task worktree)
  # - `images` - Optional list of image attachments (base64 data URLs)
  #
  # This handler also moves the task to "In Progress" if it's not already there.
  # The BE handles all the logic - FE just sends the message.
  @impl true
  def handle_in("start_executor", params, socket) do
    task_id = socket.assigns.task_id

    # Reload task to get fresh data (title, description, column)
    case Task.get(task_id) do
      {:ok, task} ->
        executor_type =
          params
          |> Map.get("executor_type", "claude_code")
          |> String.to_existing_atom()

        user_prompt = Map.get(params, "prompt", "")
        images = Map.get(params, "images", [])

        # Use task worktree if no working directory specified
        working_directory = Map.get(params, "working_directory") || task.worktree_path

        # Allow empty prompt if images are provided
        if user_prompt == "" and Enum.empty?(images) do
          {:reply, {:error, %{reason: "prompt_required"}}, socket}
        else
          # Move task to "In Progress" if not already there
          task = maybe_move_to_in_progress(task)

          # Check if this is the first session for this task
          # If so, prepend title and description to the prompt
          final_prompt = build_prompt_with_context(task, user_prompt)

          Logger.info(
            "[TaskChannel] Starting #{executor_type} for task #{task_id} with #{length(images)} images"
          )

          # Check if executor is available
          unless Registry.available?(executor_type) do
            {:reply, {:error, %{reason: "executor_not_available", executor_type: executor_type}},
             socket}
          else
            # Start the executor via Ash action
            case Executor.execute(task_id, final_prompt, executor_type, working_directory, images) do
              {:ok, result} ->
                # Notify TaskActor so it can subscribe to completion and handle auto-move
                Viban.Kanban.Actors.TaskActor.notify_executor_started(task_id)
                {:reply, {:ok, result}, socket}

              {:error, error} ->
                Logger.error("[TaskChannel] Failed to start executor: #{inspect(error)}")

                {:reply, {:error, %{reason: "failed_to_start_executor", details: inspect(error)}},
                 socket}
            end
          end
        end

      {:error, _} ->
        {:reply, {:error, %{reason: "task_not_found"}}, socket}
    end
  end

  # List available executors on the system.
  @impl true
  def handle_in("list_executors", _params, socket) do
    case Executor.list_available() do
      {:ok, executors} ->
        {:reply, {:ok, %{executors: executors}}, socket}

      {:error, error} ->
        {:reply, {:error, %{reason: inspect(error)}}, socket}
    end
  end

  # Get current task and executor status.
  @impl true
  def handle_in("get_status", _params, socket) do
    task_id = socket.assigns.task_id

    case Task.get(task_id) do
      {:ok, task} ->
        # Get recent executor sessions
        sessions =
          case ExecutorSession.for_task(task_id) do
            {:ok, sessions} -> Enum.map(sessions, &serialize_session/1)
            _ -> []
          end

        {:reply,
         {:ok,
          %{
            agent_status: task.agent_status,
            agent_status_message: task.agent_status_message,
            worktree_path: task.worktree_path,
            worktree_branch: task.worktree_branch,
            in_progress: task.in_progress,
            error_message: task.error_message,
            sessions: sessions
          }}, socket}

      {:error, _} ->
        {:reply, {:error, %{reason: "task_not_found"}}, socket}
    end
  end

  # Get executor session history for this task.
  @impl true
  def handle_in("get_history", _params, socket) do
    task_id = socket.assigns.task_id

    case ExecutorSession.for_task(task_id) do
      {:ok, sessions} ->
        {:reply, {:ok, %{sessions: Enum.map(sessions, &serialize_session/1)}}, socket}

      {:error, reason} ->
        Logger.error("[TaskChannel] Failed to get session history: #{inspect(reason)}")
        {:reply, {:error, %{reason: "failed_to_get_history"}}, socket}
    end
  end

  # Stop the currently running executor for this task.
  @impl true
  def handle_in("stop_executor", _params, socket) do
    task_id = socket.assigns.task_id

    case Viban.Executors.Runner.stop_by_task(task_id, :user_cancelled) do
      :ok ->
        {:reply, {:ok, %{status: "stopped"}}, socket}

      {:error, :not_running} ->
        {:reply, {:error, %{reason: "no_executor_running"}}, socket}
    end
  end

  # Get messages for this task (across all sessions).
  @impl true
  def handle_in("get_messages", _params, socket) do
    task_id = socket.assigns.task_id

    # Get all sessions for this task, ordered by most recent first
    sessions =
      case ExecutorSession.for_task(task_id) do
        {:ok, sessions} -> sessions
        _ -> []
      end

    # Get messages for each session
    messages =
      sessions
      |> Enum.flat_map(fn session ->
        case ExecutorMessage.for_session(session.id) do
          {:ok, msgs} -> Enum.map(msgs, &serialize_message(&1, session))
          _ -> []
        end
      end)
      |> Enum.sort_by(& &1.timestamp)

    {:reply, {:ok, %{messages: messages}}, socket}
  end

  defp serialize_session(session) do
    %{
      id: session.id,
      executor_type: session.executor_type,
      prompt: session.prompt,
      status: session.status,
      exit_code: session.exit_code,
      error_message: session.error_message,
      working_directory: session.working_directory,
      started_at: session.started_at,
      completed_at: session.completed_at,
      inserted_at: session.inserted_at
    }
  end

  defp serialize_message(message, session) do
    %{
      id: message.id,
      session_id: session.id,
      role: message.role,
      content: message.content,
      metadata: message.metadata,
      timestamp: message.inserted_at |> DateTime.to_iso8601(),
      executor_type: session.executor_type
    }
  end

  # Move task to "In Progress" column if it's not already there.
  # Returns the task (possibly updated with new column_id).
  defp maybe_move_to_in_progress(task) do
    alias Viban.Kanban.{Column, Task}
    alias Viban.Kanban.Actors.ColumnLookup

    # Get the task's current column to find the board_id
    case Column.get(task.column_id) do
      {:ok, column} ->
        # Check if already in "In Progress"
        if ColumnLookup.in_progress_column?(task.column_id) do
          # Already in the right column, return as-is
          task
        else
          # Find the "In Progress" column for this board
          case ColumnLookup.find_in_progress_column(column.board_id) do
            nil ->
              Logger.warning(
                "[TaskChannel] No 'In Progress' column found for board #{column.board_id}"
              )

              task

            in_progress_column_id ->
              # Move task to "In Progress" column at position 0 (top)
              case Task.move(task, %{column_id: in_progress_column_id, position: Decimal.new(0)}) do
                {:ok, updated_task} ->
                  Logger.info(
                    "[TaskChannel] Moved task #{task.id} to 'In Progress' column"
                  )

                  updated_task

                {:error, error} ->
                  Logger.error(
                    "[TaskChannel] Failed to move task to 'In Progress': #{inspect(error)}"
                  )

                  task
              end
          end
        end

      {:error, _} ->
        Logger.error("[TaskChannel] Could not find column for task #{task.id}")
        task
    end
  end

  # Build the prompt, prepending title and description for the first session only
  defp build_prompt_with_context(task, user_prompt) do
    # Check if there are any existing sessions for this task
    has_previous_sessions =
      case ExecutorSession.for_task(task.id) do
        {:ok, sessions} -> length(sessions) > 0
        _ -> false
      end

    if has_previous_sessions do
      # Not the first session - just use user's prompt
      user_prompt
    else
      # First session - prepend title and description
      context_parts = [task.title]

      context_parts =
        case task.description do
          nil -> context_parts
          "" -> context_parts
          desc -> context_parts ++ [desc]
        end

      context_parts =
        if user_prompt != "" do
          context_parts ++ [user_prompt]
        else
          context_parts
        end

      Enum.join(context_parts, "\n\n")
    end
  end
end
