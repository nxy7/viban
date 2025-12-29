defmodule Viban.Kanban.Actors.TaskActor do
  @moduledoc """
  Manages the lifecycle of hooks and commands for a single task.

  ## Responsibilities

  - Execute commands sequentially via command queue
  - On column change: queue entry hooks for the new column
  - Handle executor lifecycle with completion callbacks
  - Maintain worktree path
  - Track and broadcast the currently executing hook name

  ## Command Queue Pattern

  All operations (hooks, executor, moves) are executed through a command queue.
  This ensures:
  - Sequential execution (no race conditions)
  - Interruptible operations (moving task cancels current work)
  - Completion callbacks (executor can trigger move on completion)

  ## State

  The actor maintains:
  - `board_id` - the board this task belongs to
  - `task_id` - unique task identifier
  - `current_column_id` - current column location
  - `worktree_path` - git worktree path for this task
  - `worktree_branch` - branch name in the worktree
  - `current_hook_name` - name of currently executing hook (broadcasted to UI)
  - `command_queue` - queue of pending commands

  ## Lifecycle

  Uses `:transient` restart strategy - only restarts on abnormal termination.
  On normal termination, conditionally removes worktree.
  """
  use GenServer, restart: :transient
  require Logger

  alias Viban.Kanban.{Column, ColumnHook, Hook, Task, WorktreeManager}
  alias Viban.Kanban.Actors.{ColumnLookup, ColumnSemaphore, CommandQueue, HookRunner}
  alias Viban.Executors.Runner
  alias Phoenix.PubSub

  # Registry for actor lookups
  @registry Viban.Kanban.ActorRegistry

  # PubSub name
  @pubsub Viban.PubSub

  # Maximum length of error output to include in error messages
  @max_error_output_length 200

  @type state :: %__MODULE__{
          board_id: String.t(),
          task_id: String.t(),
          current_column_id: String.t() | nil,
          worktree_path: String.t() | nil,
          worktree_branch: String.t() | nil,
          custom_branch_name: String.t() | nil,
          current_hook_name: String.t() | nil,
          command_queue: CommandQueue.t(),
          executor_running: boolean(),
          awaiting_executor_hook_id: String.t() | nil
        }

  defstruct [
    :board_id,
    :task_id,
    :current_column_id,
    :worktree_path,
    :worktree_branch,
    :custom_branch_name,
    :current_hook_name,
    command_queue: nil,
    executor_running: false,
    awaiting_executor_hook_id: nil
  ]

  # ============================================================================
  # Client API
  # ============================================================================

  @doc """
  Starts the TaskActor for a specific task.
  """
  @spec start_link({String.t(), Task.t()}) :: GenServer.on_start()
  def start_link({board_id, task}) do
    GenServer.start_link(__MODULE__, {board_id, task}, name: via_tuple(task.id))
  end

  @doc """
  Returns the via tuple for registry lookup.
  """
  @spec via_tuple(String.t()) :: {:via, Registry, {atom(), term()}}
  def via_tuple(task_id) do
    {:via, Registry, {@registry, {:task_actor, task_id}}}
  end

  @doc """
  Notify the TaskActor that an executor was started externally (e.g., via channel).
  This allows the TaskActor to subscribe to completion events and handle auto-move.
  """
  @spec notify_executor_started(String.t()) :: :ok | {:error, :not_found}
  def notify_executor_started(task_id) do
    case Registry.lookup(@registry, {:task_actor, task_id}) do
      [{pid, _}] ->
        GenServer.cast(pid, :executor_started_externally)
        :ok

      [] ->
        {:error, :not_found}
    end
  end

  # ============================================================================
  # Server Callbacks
  # ============================================================================

  @impl true
  def init({board_id, task}) do
    Logger.info("TaskActor starting for task #{task.id}")

    state = %__MODULE__{
      board_id: board_id,
      task_id: task.id,
      current_column_id: task.column_id,
      worktree_path: task.worktree_path,
      worktree_branch: task.worktree_branch,
      custom_branch_name: task.custom_branch_name,
      current_hook_name: nil,
      command_queue: CommandQueue.new(),
      executor_running: false
    }

    # Subscribe to execution trigger (from semaphore when slot becomes available)
    PubSub.subscribe(@pubsub, "task:#{task.id}:execute")

    # Defer initialization to avoid blocking the supervisor
    send(self(), :init_hooks)

    {:ok, state}
  end

  @impl true
  def handle_info(:init_hooks, state) do
    state =
      state
      |> maybe_create_worktree()
      |> queue_column_entry_commands(state.current_column_id)
      |> maybe_process_next_command()

    {:noreply, state}
  end

  @impl true
  def handle_info(:process_next_command, state) do
    {:noreply, maybe_process_next_command(state)}
  end

  @impl true
  def handle_info({:command_complete, result}, state) do
    state = handle_command_complete(state, result)
    {:noreply, state}
  end

  @impl true
  def handle_info({:executor_completed, exit_code}, state) do
    Logger.info("Task #{state.task_id} executor completed with exit code #{exit_code}")
    state = handle_executor_completion(state, exit_code)
    {:noreply, state}
  end

  @impl true
  def handle_cast(:executor_started_externally, state) do
    Logger.info("Task #{state.task_id} executor started externally (via hook or channel)")

    # Subscribe to executor completion
    PubSub.subscribe(@pubsub, "executor:#{state.task_id}:completed")

    {:noreply, %{state | executor_running: true}}
  end

  @impl true
  def handle_cast({:task_updated, new_task}, state) do
    Logger.debug(
      "TaskActor #{state.task_id}: Received task_updated, current=#{state.current_column_id}, new=#{new_task.column_id}"
    )

    if new_task.column_id != state.current_column_id do
      Logger.info(
        "Task #{state.task_id} moved from column #{state.current_column_id} to #{new_task.column_id}"
      )

      state = handle_column_change(state, state.current_column_id, new_task.column_id)
      {:noreply, %{state | current_column_id: new_task.column_id}}
    else
      Logger.debug("TaskActor #{state.task_id}: Column unchanged, no hooks to execute")
      {:noreply, state}
    end
  end

  @impl true
  def terminate(reason, state) do
    Logger.info("TaskActor #{state.task_id} terminating: #{inspect(reason)}")

    stop_executor_sync(state.task_id)
    maybe_cleanup_worktree(state)

    :ok
  end

  # ============================================================================
  # Command Queue Processing
  # ============================================================================

  defp maybe_process_next_command(%{command_queue: queue} = state) do
    if CommandQueue.executing?(queue) do
      # Already executing a command
      state
    else
      case CommandQueue.pop(queue) do
        {:ok, command, new_queue} ->
          state = %{state | command_queue: new_queue}
          execute_command(state, command)

        :empty ->
          # All commands processed - finalize hook execution
          finalize_hook_execution(state.task_id)
          state
      end
    end
  end

  defp execute_command(state, %{type: :hook_entry} = command) do
    %{data: %{column_hook: column_hook, hook: hook}} = command

    # Update hook status in database to running
    update_hook_queue_status(state.task_id, column_hook.id, "running")

    # For transparent hooks, don't change task status (preserve error state, don't show "working")
    # For normal hooks, set the current hook which updates agent_status and in_progress
    state =
      if column_hook.transparent do
        %{state | current_hook_name: hook.name}
      else
        set_current_hook(state, hook.name)
      end

    # Get fresh task for hook execution
    task_result = Task.get(state.task_id)

    case task_result do
      {:ok, task} ->
        # Pass board_id and hook_settings to hooks (used by system hooks like PlaySound)
        hook_opts = [
          board_id: state.board_id,
          hook_settings: column_hook.hook_settings || %{}
        ]

        # Use HookRunner.execute which handles all hook types (system, script, agent)
        case HookRunner.execute(hook, task, nil, hook_opts) do
          {:ok, _} ->
            mark_hook_executed_if_needed(column_hook, state.task_id)
            update_hook_queue_status(state.task_id, column_hook.id, "completed")

            # For transparent hooks, just clear the hook name without touching task status
            state =
              if column_hook.transparent do
                clear_current_hook_name_only(state)
              else
                clear_current_hook(state)
              end

            complete_command(state, :ok)

          {:await_executor, _task_id} ->
            # Hook started an async executor (e.g., Execute AI)
            # Keep the hook in "running" status - it will be completed when executor finishes
            # Store the column_hook_id so we can complete it when executor finishes
            Logger.info("Hook '#{hook.name}' awaiting executor completion for task #{state.task_id}")
            state = %{state | awaiting_executor_hook_id: column_hook.id}
            # Don't complete the command yet - executor completion handler will do it
            state

          {:error, reason} ->
            error_message = format_error_message(hook.name, reason)

            # Transparent hooks don't affect task status or cancel other hooks
            if column_hook.transparent do
              Logger.warning("Transparent hook '#{hook.name}' failed: #{error_message}")
              update_hook_queue_status(state.task_id, column_hook.id, "failed", error_message)
              state = clear_current_hook_name_only(state)
              # Continue with remaining hooks
              complete_command(state, :ok)
            else
              set_task_error(state.task_id, hook.name, reason, state.board_id)
              update_hook_queue_status(state.task_id, column_hook.id, "failed", error_message)
              state = clear_current_hook(state)
              # Mark remaining hooks as cancelled and clear queue
              cancel_pending_hooks_in_db(state.task_id)
              state = %{state | command_queue: CommandQueue.clear(state.command_queue)}
              complete_command(state, {:error, reason})
            end
        end

      {:error, _} ->
        Logger.error("Task #{state.task_id} not found for hook execution")
        state = clear_current_hook(state)
        complete_command(state, {:error, :task_not_found})
    end
  end

  defp execute_command(state, %{type: :move_task} = command) do
    %{data: %{column_id: target_column_id}} = command

    case Task.get(state.task_id) do
      {:ok, task} ->
        # Only move if not already in target column
        if task.column_id != target_column_id do
          Logger.info("Moving task #{state.task_id} to column #{target_column_id}")
          Task.move(task, %{column_id: target_column_id})
        end

      {:error, _} ->
        :ok
    end

    complete_command(state, :ok)
  end

  defp execute_command(state, %{type: :notify_semaphore_leave} = command) do
    %{data: %{column_id: column_id}} = command
    ColumnSemaphore.task_left_column(column_id, state.task_id)
    complete_command(state, :ok)
  end

  defp execute_command(state, %{type: unknown}) do
    Logger.warning("Unknown command type: #{inspect(unknown)}")
    complete_command(state, {:error, :unknown_command})
  end

  defp complete_command(state, result) do
    queue = CommandQueue.complete_current(state.command_queue)
    current_command = CommandQueue.current(state.command_queue)

    # Handle on_complete callback
    queue =
      if current_command && current_command[:on_complete] do
        case current_command.on_complete.(result) do
          :ok -> queue
          {:queue, commands} -> CommandQueue.push_all(queue, commands)
        end
      else
        queue
      end

    state = %{state | command_queue: queue}

    # Schedule next command processing
    send(self(), :process_next_command)
    state
  end

  defp handle_command_complete(state, result) do
    complete_command(state, result)
  end

  defp handle_executor_completion(state, exit_code) do
    state = %{state | executor_running: false}

    # If we were awaiting executor completion for a hook, complete it now
    state =
      if state.awaiting_executor_hook_id do
        hook_id = state.awaiting_executor_hook_id
        Logger.info("Completing awaiting hook #{hook_id} after executor completion")

        if exit_code == 0 do
          update_hook_queue_status(state.task_id, hook_id, "completed")
        else
          error_message = "Executor failed with exit code #{exit_code}"
          update_hook_queue_status(state.task_id, hook_id, "failed", error_message)
        end

        # Clear the awaiting hook and complete the command to continue processing
        state = %{state | awaiting_executor_hook_id: nil}
        complete_command(state, if(exit_code == 0, do: :ok, else: {:error, :executor_failed}))
      else
        state
      end

    # Update task status and move to "To Review"
    case Task.get(state.task_id) do
      {:ok, task} ->
        # Set status based on exit code - error state persists on the card
        agent_status = if exit_code == 0, do: :idle, else: :error

        message =
          if exit_code == 0,
            do: "Completed successfully",
            else: "Failed with exit code #{exit_code}"

        Task.update_agent_status(task, %{
          agent_status: agent_status,
          agent_status_message: message
        })

        Task.set_in_progress(task, %{in_progress: false})

        # Always move to "To Review" regardless of exit code
        # If there was an error, the task will show error state in "To Review"
        to_review_column_id = ColumnLookup.find_to_review_column(state.board_id)

        if to_review_column_id do
          status_desc =
            if exit_code == 0,
              do: "successful completion",
              else: "failure (exit code #{exit_code})"

          Logger.info("Moving task #{state.task_id} to 'To Review' after #{status_desc}")
          Task.move(task, %{column_id: to_review_column_id})
        end

      {:error, _} ->
        :ok
    end

    # Clear current hook name since executor completed
    clear_current_hook(state)
  end

  # ============================================================================
  # Column Change Handling
  # ============================================================================

  @spec handle_column_change(state(), String.t() | nil, String.t()) :: state()
  defp handle_column_change(state, old_column_id, new_column_id) do
    # If executor is running, stop it when task moves
    state =
      if state.executor_running do
        Logger.info("Task #{state.task_id} moved - stopping executor")
        stop_executor_sync(state.task_id)
        %{state | executor_running: false, command_queue: CommandQueue.clear(state.command_queue)}
      else
        # Just clear any pending commands
        %{state | command_queue: CommandQueue.clear(state.command_queue)}
      end

    # Mark any pending/running hooks as cancelled in DB (task was moved)
    cancel_pending_hooks_in_db(state.task_id)

    # Queue cleanup for old column, then entry for new column
    state
    |> queue_column_leave_commands(old_column_id)
    |> queue_column_entry_commands(new_column_id)
    |> maybe_process_next_command()
  end

  defp queue_column_leave_commands(state, nil), do: state

  defp queue_column_leave_commands(state, column_id) do
    # Queue semaphore notification
    notify_command = %{type: :notify_semaphore_leave, data: %{column_id: column_id}}

    %{state | command_queue: CommandQueue.push_all(state.command_queue, [notify_command])}
  end

  defp queue_column_entry_commands(state, nil), do: state

  defp queue_column_entry_commands(state, column_id) do
    Logger.info("TaskActor #{state.task_id}: Queuing entry commands for column #{column_id}")
    task = get_task_or_nil(state.task_id)

    # Check if hooks are enabled for this column
    hooks_enabled = column_hooks_enabled?(column_id)
    Logger.info("TaskActor #{state.task_id}: Hooks enabled? #{hooks_enabled}")

    unless hooks_enabled do
      Logger.info("Hooks disabled for column #{column_id}, skipping entry hooks")
    end

    task_in_error = task && task.agent_status == :error
    executed_hooks = (task && task.executed_hooks) || []

    # Get all on_entry hooks for this column
    entry_hooks = get_hooks_for_column(column_id)
    Logger.info("TaskActor #{state.task_id}: Found #{length(entry_hooks)} hooks for column")

    # Filter by execute_once
    entry_hooks =
      Enum.filter(entry_hooks, fn {column_hook, _hook} ->
        not (column_hook.execute_once and column_hook.id in executed_hooks)
      end)

    # If hooks are disabled, skip all hooks
    if not hooks_enabled do
      now = DateTime.utc_now() |> DateTime.to_iso8601()

      skipped_queue =
        Enum.map(entry_hooks, fn {column_hook, hook} ->
          %{"id" => column_hook.id, "name" => hook.name, "status" => "skipped", "skip_reason" => "disabled"}
        end)

      set_hook_queue(state.task_id, skipped_queue)

      # Record skipped hooks to history
      Enum.each(entry_hooks, fn {column_hook, hook} ->
        history_entry = %{
          "id" => column_hook.id,
          "name" => hook.name,
          "status" => "skipped",
          "skip_reason" => "disabled",
          "executed_at" => now
        }

        case Task.get(state.task_id) do
          {:ok, fresh_task} ->
            Task.append_hook_history(fresh_task, history_entry)

          _ ->
            :ok
        end
      end)

      state
    else
      # Split hooks into transparent and non-transparent
      {transparent_hooks, normal_hooks} =
        Enum.split_with(entry_hooks, fn {column_hook, _hook} -> column_hook.transparent end)

      # If task is in error state:
      # - Skip non-transparent hooks
      # - Execute transparent hooks
      {hooks_to_execute, hooks_to_skip} =
        if task_in_error do
          {transparent_hooks, normal_hooks}
        else
          {entry_hooks, []}
        end

      now = DateTime.utc_now() |> DateTime.to_iso8601()

      # Build the hook queue: skipped hooks + pending hooks to execute
      skipped_queue =
        Enum.map(hooks_to_skip, fn {column_hook, hook} ->
          %{"id" => column_hook.id, "name" => hook.name, "status" => "skipped", "skip_reason" => "error", "inserted_at" => now}
        end)

      pending_queue =
        Enum.map(hooks_to_execute, fn {column_hook, hook} ->
          %{
            "id" => column_hook.id,
            "name" => hook.name,
            "status" => "pending",
            "hook_settings" => column_hook.hook_settings || %{},
            "inserted_at" => now
          }
        end)

      set_hook_queue(state.task_id, skipped_queue ++ pending_queue)

      # Record skipped hooks to history
      Enum.each(hooks_to_skip, fn {column_hook, hook} ->
        history_entry = %{
          "id" => column_hook.id,
          "name" => hook.name,
          "status" => "skipped",
          "skip_reason" => "error",
          "inserted_at" => now,
          "executed_at" => now
        }

        case Task.get(state.task_id) do
          {:ok, fresh_task} ->
            Task.append_hook_history(fresh_task, history_entry)

          _ ->
            :ok
        end
      end)

      Logger.info(
        "TaskActor #{state.task_id}: Queuing #{length(hooks_to_execute)} hooks: #{Enum.map(hooks_to_execute, fn {_, h} -> h.name end) |> Enum.join(", ")}"
      )

      entry_commands =
        Enum.map(hooks_to_execute, fn {column_hook, hook} ->
          %{type: :hook_entry, data: %{column_hook: column_hook, hook: hook}}
        end)

      %{state | command_queue: CommandQueue.push_all(state.command_queue, entry_commands)}
    end
  end

  # ============================================================================
  # Hook Management
  # ============================================================================

  # Get all hooks for a column, sorted by position.
  # Returns a list of {column_hook, hook} tuples.
  defp get_hooks_for_column(column_id) do
    case ColumnHook.read() do
      {:ok, column_hooks} ->
        column_hooks
        |> Enum.filter(&(&1.column_id == column_id))
        |> Enum.sort_by(& &1.position)
        |> Enum.map(fn ch ->
          case get_hook(ch.hook_id) do
            {:ok, hook} -> {ch, hook}
            _ -> nil
          end
        end)
        |> Enum.reject(&is_nil/1)

      _ ->
        []
    end
  end

  # Get hook by ID - checks both database hooks and system hooks from Registry
  defp get_hook(hook_id) do
    alias Viban.Kanban.SystemHooks.Registry

    if Registry.system_hook?(hook_id) do
      Registry.get(hook_id)
    else
      Hook.get(hook_id)
    end
  end

  # Check if hooks are enabled for a column (defaults to true if not set)
  defp column_hooks_enabled?(column_id) do
    case Column.get(column_id) do
      {:ok, column} ->
        # Default to true if not explicitly set to false
        column.settings["hooks_enabled"] != false

      _ ->
        # Column not found, assume hooks enabled to not break existing behavior
        true
    end
  end

  defp mark_hook_executed_if_needed(column_hook, task_id) do
    if column_hook.execute_once do
      case Task.get(task_id) do
        {:ok, task} -> Task.mark_hook_executed(task, column_hook.id)
        _ -> :ok
      end
    end
  end

  # Set and broadcast the current hook name with "Executing" prefix
  defp set_current_hook(state, hook_name) do
    Logger.info("Task #{state.task_id}: Setting status to 'Executing #{hook_name}'")

    # Update task agent_status_message to show current hook
    # Also set in_progress so the frontend shows the status badge
    case Task.get(state.task_id) do
      {:ok, task} ->
        Task.update_agent_status(task, %{
          agent_status: :executing,
          agent_status_message: "Executing #{hook_name}"
        })

        Task.set_in_progress(task, %{in_progress: true})

      _ ->
        :ok
    end

    %{state | current_hook_name: hook_name}
  end

  # Clear current hook and reset agent status to idle
  defp clear_current_hook(state) do
    Logger.info("TaskActor #{state.task_id}: Clearing current hook")

    case Task.get(state.task_id) do
      {:ok, task} ->
        Logger.info("TaskActor #{state.task_id}: agent_status=#{task.agent_status}, in_progress=#{task.in_progress}")
        # Only clear if still in executing state (don't override error state)
        if task.agent_status == :executing do
          Logger.info("TaskActor #{state.task_id}: Setting status to idle and in_progress to false")
          Task.update_agent_status(task, %{
            agent_status: :idle,
            agent_status_message: nil
          })

          Task.set_in_progress(task, %{in_progress: false})
        else
          Logger.info("TaskActor #{state.task_id}: Status is #{task.agent_status}, not clearing")
        end

      _ ->
        :ok
    end

    %{state | current_hook_name: nil}
  end

  # Clear current hook name only, without touching task status
  # Used for transparent hooks which should not affect task agent_status or in_progress
  defp clear_current_hook_name_only(state) do
    %{state | current_hook_name: nil}
  end

  # ============================================================================
  # Hook Queue Database Operations
  # ============================================================================

  # Set the entire hook queue for a task
  defp set_hook_queue(task_id, hook_queue) do
    case Task.get(task_id) do
      {:ok, task} ->
        Task.update_hook_queue(task, %{hook_queue: hook_queue})

      _ ->
        :ok
    end
  end

  # Final statuses that should be recorded in hook history
  @final_statuses ["completed", "failed", "cancelled", "skipped"]

  # Update a single hook's status in the queue
  # Also records to hook_history when transitioning to a final status
  # Optional error_message is stored for failed hooks
  defp update_hook_queue_status(task_id, hook_id, new_status, error_message \\ nil) do
    case Task.get(task_id) do
      {:ok, task} ->
        # Find the hook entry to get its name for history
        hook_entry = Enum.find(task.hook_queue || [], &(&1["id"] == hook_id))

        updated_queue =
          Enum.map(task.hook_queue || [], fn hook ->
            if hook["id"] == hook_id do
              hook
              |> Map.put("status", new_status)
              |> then(fn h ->
                if error_message, do: Map.put(h, "error_message", error_message), else: h
              end)
            else
              hook
            end
          end)

        Task.update_hook_queue(task, %{hook_queue: updated_queue})

        # Record to history when transitioning to a final status
        if hook_entry && new_status in @final_statuses do
          history_entry =
            %{
              "id" => hook_id,
              "name" => hook_entry["name"],
              "status" => new_status,
              "inserted_at" => hook_entry["inserted_at"],
              "executed_at" => DateTime.utc_now() |> DateTime.to_iso8601()
            }
            |> then(fn entry ->
              if error_message, do: Map.put(entry, "error_message", error_message), else: entry
            end)

          # Re-fetch task to get updated state and append to history
          case Task.get(task_id) do
            {:ok, fresh_task} ->
              Task.append_hook_history(fresh_task, history_entry)

            _ ->
              :ok
          end
        end

      _ ->
        :ok
    end
  end

  # Mark all pending/running hooks as cancelled in the database
  # Also records cancelled hooks to history
  defp cancel_pending_hooks_in_db(task_id) do
    case Task.get(task_id) do
      {:ok, task} ->
        now = DateTime.utc_now() |> DateTime.to_iso8601()

        # Find hooks to cancel and update queue
        {updated_queue, cancelled_hooks} =
          Enum.map_reduce(task.hook_queue || [], [], fn hook, acc ->
            if hook["status"] in ["pending", "running"] do
              cancelled = Map.put(hook, "status", "cancelled")
              {cancelled, [hook | acc]}
            else
              {hook, acc}
            end
          end)

        Task.update_hook_queue(task, %{hook_queue: updated_queue})

        # Record cancelled hooks to history
        Enum.each(cancelled_hooks, fn hook ->
          history_entry = %{
            "id" => hook["id"],
            "name" => hook["name"],
            "status" => "cancelled",
            "inserted_at" => hook["inserted_at"],
            "executed_at" => now
          }

          case Task.get(task_id) do
            {:ok, fresh_task} ->
              Task.append_hook_history(fresh_task, history_entry)

            _ ->
              :ok
          end
        end)

      _ ->
        :ok
    end
  end

  # Called when the command queue becomes empty after processing hooks.
  # Clears the hook queue. History is already recorded by update_hook_queue_status.
  defp finalize_hook_execution(task_id) do
    case Task.get(task_id) do
      {:ok, task} ->
        hook_queue = task.hook_queue || []

        # Only finalize if there are hooks to clear
        if Enum.any?(hook_queue) do
          # Clear the hook queue (history was already recorded in update_hook_queue_status)
          case Task.get(task_id) do
            {:ok, fresh_task} ->
              Task.update_hook_queue(fresh_task, %{hook_queue: []})
              Logger.debug("TaskActor #{task_id}: Finalized hook execution, cleared #{length(hook_queue)} hooks from queue")

            _ ->
              :ok
          end
        end

      _ ->
        :ok
    end
  end

  # ============================================================================
  # Executor Management
  # ============================================================================

  defp stop_executor_sync(task_id) do
    case Runner.stop_by_task(task_id, :user_cancelled) do
      :ok ->
        Logger.info("Stopped executor for task #{task_id}")

      {:error, :not_running} ->
        :ok

      {:error, err} ->
        Logger.warning("Failed to stop executor for task #{task_id}: #{inspect(err)}")
    end
  end

  # ============================================================================
  # Worktree Management
  # ============================================================================

  defp maybe_create_worktree(%{worktree_path: nil} = state) do
    case WorktreeManager.create_worktree(
           state.board_id,
           state.task_id,
           state.custom_branch_name
         ) do
      {:ok, worktree_path, branch_name} ->
        update_task_worktree(state.task_id, worktree_path, branch_name)

        %{state | worktree_path: worktree_path, worktree_branch: branch_name}

      {:error, reason} ->
        Logger.warning("Failed to create worktree: #{inspect(reason)}")
        state
    end
  end

  defp maybe_create_worktree(state), do: state

  defp update_task_worktree(task_id, worktree_path, branch_name) do
    case Task.get(task_id) do
      {:ok, task} ->
        Task.assign_worktree(task, %{
          worktree_path: worktree_path,
          worktree_branch: branch_name
        })

      _ ->
        :ok
    end
  end

  defp maybe_cleanup_worktree(state) do
    case Task.get(state.task_id) do
      {:ok, _task} ->
        # Task still exists, don't clean up worktree
        :ok

      {:error, _} ->
        # Task was deleted, clean up worktree
        if state.worktree_path do
          Logger.info("Task #{state.task_id} was deleted, cleaning up worktree")

          WorktreeManager.remove_worktree(
            state.task_id,
            state.worktree_path,
            state.worktree_branch,
            add_activity: false
          )
        end
    end
  end

  # ============================================================================
  # Error Handling
  # ============================================================================

  defp set_task_error(task_id, hook_name, reason, board_id) do
    error_message = format_error_message(hook_name, reason)
    Logger.error("Task #{task_id} hook '#{hook_name}' failed: #{error_message}")

    case Task.get(task_id) do
      {:ok, task} ->
        Task.set_error(task, %{
          agent_status: :error,
          error_message: error_message,
          in_progress: false
        })

        # Move to "To Review" with error state visible on the card
        to_review_column_id = ColumnLookup.find_to_review_column(board_id)

        if to_review_column_id do
          Logger.info("Moving task #{task_id} to 'To Review' after hook failure")
          Task.move(task, %{column_id: to_review_column_id})
        end

      _ ->
        :ok
    end
  end

  @spec format_error_message(String.t(), term()) :: String.t()
  defp format_error_message(hook_name, {:exit_code, code, output}) do
    truncated = String.slice(output || "", 0, @max_error_output_length)
    "Hook '#{hook_name}' failed with exit code #{code}: #{truncated}"
  end

  defp format_error_message(hook_name, :timeout) do
    "Hook '#{hook_name}' timed out"
  end

  defp format_error_message(hook_name, reason) do
    "Hook '#{hook_name}' failed: #{inspect(reason)}"
  end

  # ============================================================================
  # Helpers
  # ============================================================================

  @spec get_task_or_nil(String.t()) :: Task.t() | nil
  defp get_task_or_nil(task_id) do
    case Task.get(task_id) do
      {:ok, task} -> task
      _ -> nil
    end
  end
end
