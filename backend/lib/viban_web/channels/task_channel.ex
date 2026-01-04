defmodule VibanWeb.TaskChannel do
  @moduledoc """
  Phoenix Channel for task communication.

  Handles real-time communication between users and executor agents
  for a specific task. Supports:
  - Sending messages (queued for AI execution)
  - Receiving executor output streams
  - Getting task/executor status
  - Message history
  - Stopping running executors

  ## AI Execution Flow

  When a user sends a message via `send_message`:
  1. Message is queued on the task's `message_queue`
  2. Task is moved to "In Progress" column (if not already there)
  3. Execute AI hook processes queued messages until queue is empty

  ## Events

  ### Incoming (client -> server)
  - `send_message` - Queue a message and move task to "In Progress"
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
  alias Viban.Executors.{Executor, ExecutorSession, ExecutorMessage}

  require Logger

  @impl true
  def join("task:" <> task_id, _params, socket) do
    Logger.info("[TaskChannel] Joining task:#{task_id}")

    case Task.get(task_id) do
      {:ok, task} ->
        socket =
          socket
          |> assign(:task_id, task_id)
          |> assign(:task, task)

        Logger.info("[TaskChannel] Successfully joined task:#{task_id}")
        {:ok, %{task_id: task_id}, socket}

      {:error, reason} ->
        Logger.warning("[TaskChannel] Failed to join task:#{task_id}: #{inspect(reason)}")
        {:error, %{reason: "task_not_found"}}
    end
  end

  # Queue a message and move task to "In Progress" for AI execution.
  #
  # This handler:
  # 1. Queues the message on the task's message_queue
  # 2. Moves the task to "In Progress" column (if not already there)
  # 3. The Execute AI hook will process queued messages
  #
  # Params:
  # - `executor_type` - Atom type of executor (e.g., "claude_code", "gemini_cli")
  # - `prompt` - The prompt/instruction for the executor
  # - `images` - Optional list of image attachments (base64 data URLs)
  @impl true
  def handle_in("send_message", params, socket) do
    alias Viban.Kanban.Column
    alias Viban.Kanban.Actors.ColumnLookup
    alias Viban.Kanban.Message

    task_id = socket.assigns.task_id

    case Task.get(task_id) do
      {:ok, task} ->
        executor_type =
          params
          |> Map.get("executor_type", "claude_code")
          |> String.to_existing_atom()

        user_prompt = Map.get(params, "prompt", "")
        images = Map.get(params, "images", [])

        # Allow empty prompt if images are provided
        if user_prompt == "" and Enum.empty?(images) do
          {:reply, {:error, %{reason: "prompt_required"}}, socket}
        else
          # Save the user message immediately to the Message table (synced via Electric)
          image_count = length(images)

          display_content =
            if image_count > 0 do
              suffix = if image_count > 1, do: "s", else: ""
              "#{user_prompt}#{if user_prompt != "", do: "\n\n", else: ""}[#{image_count} image#{suffix} attached]"
            else
              user_prompt
            end

          case Message.create(%{
                 task_id: task_id,
                 role: :user,
                 content: display_content,
                 status: :pending,
                 metadata: %{executor_type: executor_type, images: images}
               }) do
            {:ok, _message} ->
              Logger.info("[TaskChannel] Saved user message for task #{task_id}")

            {:error, error} ->
              Logger.warning("[TaskChannel] Failed to save message: #{inspect(error)}")
          end

          # Queue the message on the task for processing
          case Task.queue_message(task, user_prompt, executor_type, images) do
            {:ok, updated_task} ->
              Logger.info(
                "[TaskChannel] Queued message for task #{task_id}, queue size: #{length(updated_task.message_queue)}"
              )

              # Move task to "In Progress" if not already there
              updated_task = maybe_move_to_in_progress(updated_task)

              {:reply, {:ok, %{queued: true, queue_size: length(updated_task.message_queue)}},
               socket}

            {:error, error} ->
              Logger.error("[TaskChannel] Failed to queue message: #{inspect(error)}")
              {:reply, {:error, %{reason: "failed_to_queue", details: inspect(error)}}, socket}
          end
        end

      {:error, _} ->
        {:reply, {:error, %{reason: "task_not_found"}}, socket}
    end
  end

  # List available executors on the system.
  @impl true
  def handle_in("list_executors", _params, socket) do
    Logger.info("[TaskChannel] list_executors called for task #{socket.assigns.task_id}")

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

  # Stop the currently running executor and cancel pending hooks for this task.
  @impl true
  def handle_in("stop_executor", _params, socket) do
    task_id = socket.assigns.task_id

    Viban.Kanban.Servers.TaskServer.stop_execution(task_id)

    case Viban.Executors.Runner.stop_by_task(task_id, :user_cancelled) do
      :ok ->
        {:reply, {:ok, %{status: "stopped"}}, socket}

      {:error, :not_running} ->
        {:reply, {:ok, %{status: "stopped"}}, socket}
    end
  end

  # Create worktree for this task.
  @impl true
  def handle_in("create_worktree", _params, socket) do
    task_id = socket.assigns.task_id

    case Task.create_worktree(task_id) do
      {:ok, result} ->
        {:reply,
         {:ok,
          %{
            worktree_path: result.worktree_path,
            worktree_branch: result.worktree_branch
          }}, socket}

      {:error, error} when is_binary(error) ->
        {:reply, {:error, %{reason: error}}, socket}

      {:error, error} ->
        {:reply, {:error, %{reason: inspect(error)}}, socket}
    end
  end

  # Get messages for this task (across all sessions).
  @impl true
  def handle_in("get_messages", _params, socket) do
    task_id = socket.assigns.task_id
    Logger.info("[TaskChannel] get_messages called for task #{task_id}")

    # Get all sessions for this task, ordered by most recent first
    sessions =
      case ExecutorSession.for_task(task_id) do
        {:ok, sessions} -> sessions
        _ -> []
      end

    # Get messages for each session
    session_messages =
      sessions
      |> Enum.flat_map(fn session ->
        case ExecutorMessage.for_session(session.id) do
          {:ok, msgs} -> Enum.map(msgs, &serialize_message(&1, session))
          _ -> []
        end
      end)

    # Get queued messages that haven't been processed yet
    queued_messages =
      case Task.get(task_id) do
        {:ok, task} ->
          (task.message_queue || [])
          |> Enum.map(fn entry ->
            %{
              id: entry.id || Ash.UUID.generate(),
              role: :user,
              content: entry.prompt || "",
              metadata: %{images: entry.images || [], queued: true},
              timestamp: entry.queued_at || DateTime.utc_now() |> DateTime.to_iso8601(),
              executor_type: entry.executor_type || "claude_code"
            }
          end)

        _ ->
          []
      end

    # Combine and sort all messages
    messages =
      (session_messages ++ queued_messages)
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

  defp maybe_move_to_in_progress(task) do
    alias Viban.Kanban.Column
    alias Viban.Kanban.Actors.ColumnLookup

    case Column.get(task.column_id) do
      {:ok, column} ->
        if ColumnLookup.in_progress_column?(task.column_id) do
          task
        else
          case ColumnLookup.find_in_progress_column(column.board_id) do
            nil ->
              Logger.warning(
                "[TaskChannel] No 'In Progress' column found for board #{column.board_id}"
              )

              task

            in_progress_column_id ->
              case Task.move(task, %{column_id: in_progress_column_id, position: 0.0}) do
                {:ok, updated_task} ->
                  Logger.info("[TaskChannel] Moved task #{task.id} to 'In Progress' column")
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
end
