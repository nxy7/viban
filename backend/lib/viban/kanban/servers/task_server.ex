defmodule Viban.Kanban.Servers.TaskServer do
  @moduledoc """
  Manages the lifecycle of a single task, including hook execution coordination.

  ## Architecture

  The TaskServer is the single coordination point for all task-related operations:
  - Spawns a HookExecutionServer child to handle sequential hook execution
  - All task moves go through this server to ensure proper hook cleanup
  - Self-heals on startup by loading pending hook executions

  ## Key Flows

  ### Task Enters Column
  1. `queue_column_hooks/2` creates HookExecution rows in database
  2. `schedule_next_hook/0` casts to HookExecutionServer
  3. HookExecutionServer runs hooks sequentially, notifying on completion

  ### Task Moved
  1. `move/3` is synchronous - waits for executor stop
  2. Cancels pending HookExecutions in database
  3. Creates new HookExecution rows for new column
  4. Schedules first hook

  ### Server Restart
  1. On init, queries for pending/running HookExecutions
  2. Marks :running as cancelled with skip_reason: :server_restart
  3. Schedules remaining :pending hooks
  """
  use GenServer, restart: :transient
  require Logger

  alias Viban.Kanban.{Column, ColumnHook, Hook, HookExecution, Task, WorktreeManager}
  alias Viban.Kanban.Servers.{HookExecutionServer, TaskSupervisor}
  alias Viban.Kanban.Actors.ColumnSemaphore
  alias Phoenix.PubSub

  @registry Viban.Kanban.ActorRegistry
  @pubsub Viban.PubSub

  @type state :: %__MODULE__{
          board_id: String.t(),
          task_id: String.t(),
          current_column_id: String.t() | nil,
          worktree_path: String.t() | nil,
          worktree_branch: String.t() | nil,
          custom_branch_name: String.t() | nil
        }

  defstruct [
    :board_id,
    :task_id,
    :current_column_id,
    :worktree_path,
    :worktree_branch,
    :custom_branch_name
  ]

  # ============================================================================
  # Client API
  # ============================================================================

  @spec start_link({String.t(), Task.t()}) :: GenServer.on_start()
  def start_link({board_id, task}) do
    GenServer.start_link(__MODULE__, {board_id, task}, name: via_tuple(task.id))
  end

  @spec via_tuple(String.t()) :: {:via, Registry, {atom(), term()}}
  def via_tuple(task_id) do
    {:via, Registry, {@registry, {:task_server, task_id}}}
  end

  @doc """
  Move a task to a new column. Synchronous - waits for executor stop.
  Called by CancelHooksOnMove change.
  """
  @spec move(String.t(), String.t(), float()) :: :ok | {:error, term()}
  def move(task_id, new_column_id, new_position) do
    case Registry.lookup(@registry, {:task_server, task_id}) do
      [{pid, _}] ->
        GenServer.call(pid, {:move, new_column_id, new_position}, 30_000)

      [] ->
        {:error, :not_found}
    end
  end

  @doc """
  Stop all hook execution for a task.
  """
  @spec stop_execution(String.t()) :: :ok | {:error, :not_found}
  def stop_execution(task_id) do
    case Registry.lookup(@registry, {:task_server, task_id}) do
      [{pid, _}] ->
        GenServer.call(pid, :stop_execution, 30_000)

      [] ->
        {:error, :not_found}
    end
  end

  @doc """
  Called by HookExecutionServer when a hook completes.
  """
  @spec hook_completed(String.t(), String.t(), :ok | {:error, term()}) :: :ok
  def hook_completed(task_id, execution_id, result) do
    case Registry.lookup(@registry, {:task_server, task_id}) do
      [{pid, _}] ->
        GenServer.cast(pid, {:hook_completed, execution_id, result})
        :ok

      [] ->
        :ok
    end
  end

  @doc """
  Notify that an external executor has started (e.g., AI agent).
  """
  @spec notify_executor_started(String.t()) :: :ok | {:error, :not_found}
  def notify_executor_started(task_id) do
    case Registry.lookup(@registry, {:task_server, task_id}) do
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
    Logger.info("Starting", task_id: task.id)

    state = %__MODULE__{
      board_id: board_id,
      task_id: task.id,
      current_column_id: task.column_id,
      worktree_path: task.worktree_path,
      worktree_branch: task.worktree_branch,
      custom_branch_name: task.custom_branch_name
    }

    PubSub.subscribe(@pubsub, "task:#{task.id}:execute")
    PubSub.subscribe(@pubsub, "executor:#{task.id}:completed")

    send(self(), :init_task)

    {:ok, state}
  end

  @impl true
  def handle_info(:init_task, state) do
    Logger.info("Initializing", task_id: state.task_id)

    state = maybe_create_worktree(state)
    self_heal(state)
    # On restart, only queue hooks that don't already have executions
    queue_column_hooks(state.task_id, state.current_column_id, state.board_id,
      restart_recovery: true
    )

    schedule_next_hook(state.task_id)

    {:noreply, state}
  end

  @impl true
  def handle_info({:executor_completed, exit_code}, state) do
    Logger.info("Executor completed with exit code #{exit_code}", task_id: state.task_id)
    handle_executor_completion(state, exit_code)
    {:noreply, state}
  end

  @impl true
  def handle_info({:task_deleted, task_id}, state) when task_id == state.task_id do
    Logger.info("Task deleted, stopping", task_id: state.task_id)
    {:stop, :normal, state}
  end

  @impl true
  def handle_info({:schedule_next_hook, task_id, retries}, state) do
    schedule_next_hook(task_id, retries)
    {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  @impl true
  def handle_call({:move, new_column_id, _new_position}, _from, state) do
    Logger.info("Moving to column #{new_column_id}", task_id: state.task_id)

    cancel_hook_executor(state.task_id)
    cancel_pending_executions(state.task_id, :column_change)

    if state.current_column_id do
      ColumnSemaphore.task_left_column(state.current_column_id, state.task_id)
    end

    # Fresh queue - always queue all applicable hooks
    queue_column_hooks(state.task_id, new_column_id, state.board_id, restart_recovery: false)
    schedule_next_hook(state.task_id)

    {:reply, :ok, %{state | current_column_id: new_column_id}}
  end

  @impl true
  def handle_call(:stop_execution, _from, state) do
    Logger.info("Stop execution requested", task_id: state.task_id)

    stop_hook_executor_sync(state.task_id)
    cancel_pending_executions(state.task_id, :user_cancelled)
    clear_task_status(state.task_id)

    {:reply, :ok, state}
  end

  @impl true
  def handle_cast({:hook_completed, execution_id, result}, state) do
    Logger.info("Hook #{execution_id} completed with #{inspect(result)}", task_id: state.task_id)
    schedule_next_hook(state.task_id)
    {:noreply, state}
  end

  @impl true
  def handle_cast(:executor_started_externally, state) do
    Logger.info("External executor started", task_id: state.task_id)
    {:noreply, state}
  end

  @impl true
  def terminate(reason, state) do
    Logger.info("Terminating: #{inspect(reason)}", task_id: state.task_id)
    maybe_cleanup_worktree(state)
    :ok
  end

  # ============================================================================
  # HookExecutionServer Management
  # ============================================================================

  defp cancel_hook_executor(task_id) do
    case TaskSupervisor.get_hook_executor(task_id) do
      {:ok, pid} ->
        case HookExecutionServer.cancel_current(pid) do
          :ok ->
            :ok

          {:error, reason} ->
            Logger.warning("Failed to cancel HookExecutionServer: #{inspect(reason)}")
        end

      {:error, :not_found} ->
        :ok
    end
  end

  defp stop_hook_executor_sync(task_id) do
    case TaskSupervisor.get_hook_executor(task_id) do
      {:ok, pid} ->
        case HookExecutionServer.stop(pid) do
          :ok ->
            :ok

          {:error, reason} ->
            Logger.warning("Failed to stop HookExecutionServer: #{inspect(reason)}")
        end

      {:error, :not_found} ->
        :ok
    end
  end

  defp schedule_next_hook(task_id, retries \\ 3) do
    case TaskSupervisor.get_hook_executor(task_id) do
      {:ok, pid} ->
        case HookExecution.pending_for_task(task_id) do
          {:ok, [next_execution | _]} ->
            HookExecutionServer.execute(pid, next_execution)

          {:ok, []} ->
            finalize_hook_execution(task_id)

          {:error, reason} ->
            Logger.error("Failed to get pending hooks: #{inspect(reason)}")
        end

      {:error, :not_found} when retries > 0 ->
        Process.send_after(self(), {:schedule_next_hook, task_id, retries - 1}, 50)

      {:error, :not_found} ->
        Logger.warning("HookExecutionServer not found for task #{task_id}")
    end
  end

  # ============================================================================
  # Self-Healing
  # ============================================================================

  defp self_heal(%{task_id: task_id}) do
    case HookExecution.active_for_task(task_id) do
      {:ok, executions} ->
        {running, pending} = Enum.split_with(executions, &(&1.status == :running))

        Enum.each(running, fn exec ->
          HookExecution.cancel(exec, %{skip_reason: :server_restart})
        end)

        if length(running) > 0 do
          Logger.info("Cancelled #{length(running)} running hooks (server restart)",
            task_id: task_id
          )
        end

        if length(pending) > 0 do
          Logger.info("Will resume #{length(pending)} pending hooks", task_id: task_id)
        end

      {:error, reason} ->
        Logger.error("Self-heal failed: #{inspect(reason)}")
    end
  end

  # ============================================================================
  # Hook Queue Management
  # ============================================================================

  defp queue_column_hooks(_task_id, nil, _board_id, _opts), do: :ok

  defp queue_column_hooks(task_id, column_id, _board_id, opts) do
    restart_recovery = Keyword.get(opts, :restart_recovery, false)

    Logger.info("Queuing hooks for column #{column_id} (restart_recovery: #{restart_recovery})",
      task_id: task_id
    )

    task = get_task_or_nil(task_id)
    hooks_enabled = column_hooks_enabled?(column_id)
    task_in_error = task && task.agent_status == :error
    executed_hooks = (task && task.executed_hooks) || []

    # On restart recovery, skip hooks that already have ANY execution record for this task+column
    # On fresh queue (from move), only skip pending/running executions (completed ones are fine to re-run)
    already_queued_column_hook_ids =
      if restart_recovery do
        case HookExecution.for_task_and_column(task_id, column_id) do
          {:ok, executions} -> Enum.map(executions, & &1.column_hook_id) |> MapSet.new()
          _ -> MapSet.new()
        end
      else
        MapSet.new()
      end

    entry_hooks = get_hooks_for_column(column_id)

    # Filter out hooks that:
    # 1. Are execute_once and already in task.executed_hooks
    # 2. Already have a HookExecution record for this task+column (only on restart recovery)
    entry_hooks =
      Enum.filter(entry_hooks, fn {column_hook, _hook} ->
        not (column_hook.execute_once and column_hook.id in executed_hooks) and
          not MapSet.member?(already_queued_column_hook_ids, column_hook.id)
      end)

    if not hooks_enabled do
      Enum.each(entry_hooks, fn {column_hook, hook} ->
        create_hook_execution(task_id, column_hook, hook, column_id, :skipped, :disabled)
      end)
    else
      {transparent_hooks, normal_hooks} =
        Enum.split_with(entry_hooks, fn {column_hook, _hook} -> column_hook.transparent end)

      {hooks_to_execute, hooks_to_skip} =
        if task_in_error do
          {transparent_hooks, normal_hooks}
        else
          {entry_hooks, []}
        end

      Enum.each(hooks_to_skip, fn {column_hook, hook} ->
        create_hook_execution(task_id, column_hook, hook, column_id, :skipped, :error)
      end)

      Enum.each(hooks_to_execute, fn {column_hook, hook} ->
        create_hook_execution(task_id, column_hook, hook, column_id, :pending, nil)
      end)

      Logger.info("Queued #{length(hooks_to_execute)} hooks", task_id: task_id)
    end
  end

  defp create_hook_execution(task_id, column_hook, hook, column_id, status, skip_reason) do
    attrs = %{
      task_id: task_id,
      hook_name: hook.name,
      hook_id: column_hook.hook_id,
      hook_settings: column_hook.hook_settings || %{},
      triggering_column_id: column_id,
      column_hook_id: column_hook.id
    }

    case HookExecution.queue(attrs) do
      {:ok, execution} ->
        if status == :skipped do
          HookExecution.skip(execution, %{skip_reason: skip_reason})
        end

        execution

      {:error, reason} ->
        Logger.error("Failed to create hook execution: #{inspect(reason)}")
        nil
    end
  end

  defp cancel_pending_executions(task_id, skip_reason) do
    case HookExecution.active_for_task(task_id) do
      {:ok, executions} ->
        Enum.each(executions, fn exec ->
          HookExecution.cancel(exec, %{skip_reason: skip_reason})
        end)

        if length(executions) > 0 do
          Logger.info("Cancelled #{length(executions)} pending executions", task_id: task_id)
        end

      {:error, reason} ->
        Logger.error("Failed to cancel executions: #{inspect(reason)}")
    end
  end

  defp finalize_hook_execution(task_id) do
    case Task.get(task_id) do
      {:ok, task} ->
        if task.agent_status == :executing do
          Task.update_agent_status(task, %{agent_status: :idle, agent_status_message: nil})
          Task.set_in_progress(task, %{in_progress: false})
        end

      _ ->
        :ok
    end
  end

  defp clear_task_status(task_id) do
    case Task.get(task_id) do
      {:ok, task} ->
        Task.update_agent_status(task, %{agent_status: :idle, agent_status_message: nil})
        Task.set_in_progress(task, %{in_progress: false})
        Task.clear_error(task)

      _ ->
        :ok
    end
  end

  # ============================================================================
  # Executor Completion
  # ============================================================================

  defp handle_executor_completion(state, exit_code) do
    alias Viban.Kanban.SystemHooks.ExecuteAIHook

    has_more_messages =
      case Task.get(state.task_id) do
        {:ok, task} -> length(task.message_queue || []) > 0
        _ -> false
      end

    if has_more_messages do
      Logger.info("Processing next queued message", task_id: state.task_id)

      case ExecuteAIHook.process_next_message(state.task_id) do
        {:await_executor, _task_id} -> :ok
        _ -> finalize_executor(state.task_id, exit_code)
      end
    else
      finalize_executor(state.task_id, exit_code)
    end
  end

  defp finalize_executor(task_id, exit_code) do
    case Task.get(task_id) do
      {:ok, task} ->
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

      {:error, _} ->
        :ok
    end
  end

  # ============================================================================
  # Hook Helpers
  # ============================================================================

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

  defp get_hook(hook_id) do
    alias Viban.Kanban.SystemHooks.Registry

    if Registry.system_hook?(hook_id) do
      Registry.get(hook_id)
    else
      Hook.get(hook_id)
    end
  end

  defp column_hooks_enabled?(column_id) do
    case Column.get(column_id) do
      {:ok, column} -> column.settings["hooks_enabled"] != false
      _ -> true
    end
  end

  # ============================================================================
  # Worktree Management
  # ============================================================================

  defp maybe_create_worktree(%{worktree_path: nil} = state) do
    case WorktreeManager.create_worktree(state.board_id, state.task_id, state.custom_branch_name) do
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
        Task.assign_worktree(task, %{worktree_path: worktree_path, worktree_branch: branch_name})

      _ ->
        :ok
    end
  end

  defp maybe_cleanup_worktree(state) do
    case Task.get(state.task_id) do
      {:ok, _task} ->
        :ok

      {:error, _} ->
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
  # Helpers
  # ============================================================================

  defp get_task_or_nil(task_id) do
    case Task.get(task_id) do
      {:ok, task} -> task
      _ -> nil
    end
  end
end
