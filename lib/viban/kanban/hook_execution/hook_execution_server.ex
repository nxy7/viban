defmodule Viban.Kanban.HookExecution.HookExecutionServer do
  @moduledoc """
  Executes hooks sequentially for a single task.

  ## Design

  This GenServer is a child of TaskServer and handles the actual execution
  of hooks one at a time. It receives HookExecution records and:

  1. Updates status to :running
  2. Executes the hook via HookRunner
  3. Updates status to :completed/:failed
  4. Notifies TaskServer to schedule next hook

  ## Stopping

  The `stop/1` function is synchronous and waits for any currently running
  hook to complete or be cancelled. This ensures clean state on task moves.
  """
  use GenServer, restart: :permanent

  alias Phoenix.PubSub
  alias Viban.CallerTracking
  alias Viban.Executors.Runner
  alias Viban.Kanban.Actors.ColumnLookup
  alias Viban.Kanban.Actors.HookRunner
  alias Viban.Kanban.ColumnHook
  alias Viban.Kanban.Hook
  alias Viban.Kanban.HookExecution
  alias Viban.Kanban.Task
  alias Viban.Kanban.Task.TaskServer

  require Logger

  @pubsub Viban.PubSub
  @max_error_output_length 200
  @executor_timeout_ms to_timeout(hour: 2)

  @type state :: %__MODULE__{
          task_id: String.t(),
          board_id: String.t(),
          current_execution_id: String.t() | nil,
          awaiting_external_executor: boolean(),
          executor_monitor_ref: reference() | nil,
          executor_timeout_ref: reference() | nil,
          script_task_ref: reference() | nil,
          script_task_pid: pid() | nil,
          stopping: boolean()
        }

  defstruct [
    :task_id,
    :board_id,
    :current_execution_id,
    :executor_monitor_ref,
    :executor_timeout_ref,
    :script_task_ref,
    :script_task_pid,
    awaiting_external_executor: false,
    stopping: false
  ]

  # ============================================================================
  # Client API
  # ============================================================================

  @registry Viban.Kanban.ActorRegistry

  @spec start_link(map()) :: GenServer.on_start()
  def start_link(args) do
    callers = CallerTracking.capture_callers()

    GenServer.start_link(__MODULE__, Map.put(args, :callers, callers), name: via_tuple(args.task_id))
  end

  defp via_tuple(task_id) do
    {:via, Registry, {@registry, {:hook_executor, task_id}}}
  end

  @doc """
  Execute a hook. Non-blocking - casts to the executor.
  """
  @spec execute(pid(), HookExecution.t()) :: :ok
  def execute(pid, execution) do
    GenServer.cast(pid, {:execute, execution})
  end

  @doc """
  Stop the executor. Synchronous - waits for cleanup.
  """
  @spec stop(pid()) :: :ok | {:error, term()}
  def stop(pid) do
    GenServer.call(pid, :stop, 30_000)
  catch
    :exit, {:noproc, _} -> :ok
    :exit, {:normal, _} -> :ok
  end

  @doc """
  Cancel current execution without stopping the server.
  Used when task moves to another column.
  """
  @spec cancel_current(pid()) :: :ok | {:error, term()}
  def cancel_current(pid) do
    GenServer.call(pid, :cancel_current, 30_000)
  catch
    :exit, {:noproc, _} -> :ok
    :exit, {:normal, _} -> :ok
  end

  # ============================================================================
  # Server Callbacks
  # ============================================================================

  @impl true
  def init(args) do
    CallerTracking.restore_callers(args[:callers] || [])

    state = %__MODULE__{
      task_id: args.task_id,
      board_id: args.board_id
    }

    PubSub.subscribe(@pubsub, "executor:#{args.task_id}:completed")

    {:ok, state}
  end

  @impl true
  def handle_cast({:execute, _execution}, %{stopping: true} = state) do
    Logger.info("Ignoring execute request, stopping", task_id: state.task_id)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:execute, execution}, state) do
    Logger.info("Starting hook #{execution.hook_name}", task_id: state.task_id)

    case HookExecution.start(execution) do
      {:ok, execution} ->
        state = %{state | current_execution_id: execution.id}
        run_hook(state, execution)

      {:error, reason} ->
        Logger.error("Failed to start execution: #{inspect(reason)}")
        TaskServer.hook_completed(state.task_id, execution.id, {:error, reason})
        {:noreply, state}
    end
  end

  @impl true
  def handle_call(:stop, from, state) do
    Logger.info("Stop requested", task_id: state.task_id)

    state = %{state | stopping: true}

    if state.executor_monitor_ref do
      Process.demonitor(state.executor_monitor_ref, [:flush])
    end

    if state.awaiting_external_executor do
      stop_external_executor(state.task_id)
    end

    if state.script_task_pid do
      kill_script_task(state)
    end

    if state.current_execution_id do
      cancel_current_execution(state)
    end

    GenServer.reply(from, :ok)
    {:stop, :normal, state}
  end

  @impl true
  def handle_call(:cancel_current, _from, state) do
    Logger.info("Cancel current requested", task_id: state.task_id)

    if state.executor_monitor_ref do
      Process.demonitor(state.executor_monitor_ref, [:flush])
    end

    if state.awaiting_external_executor do
      stop_external_executor(state.task_id)
    end

    if state.script_task_pid do
      kill_script_task(state)
    end

    if state.current_execution_id do
      cancel_current_execution(state)
    end

    new_state = %{
      state
      | current_execution_id: nil,
        awaiting_external_executor: false,
        executor_monitor_ref: nil,
        executor_timeout_ref: nil,
        script_task_ref: nil,
        script_task_pid: nil
    }

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_info({:executor_completed, exit_code}, state) do
    handle_info({:executor_completed, exit_code, nil}, state)
  end

  @impl true
  def handle_info({:executor_completed, exit_code, error_message}, state) do
    Logger.info("External executor completed with exit code #{exit_code}", task_id: state.task_id)

    if state.stopping do
      {:noreply, state}
    else
      handle_external_executor_completion(state, exit_code, error_message)
    end
  end

  @impl true
  def handle_info({:script_result, exec_id, column_hook_id, result}, state) do
    if state.stopping do
      {:noreply, state}
    else
      handle_script_result(state, exec_id, column_hook_id, result)
    end
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, reason}, %{script_task_ref: ref} = state) do
    if state.stopping do
      {:noreply, %{state | script_task_ref: nil, script_task_pid: nil}}
    else
      case reason do
        :normal ->
          {:noreply, %{state | script_task_ref: nil, script_task_pid: nil}}

        :killed ->
          Logger.info("Script task was killed", task_id: state.task_id)
          {:noreply, %{state | script_task_ref: nil, script_task_pid: nil}}

        _ ->
          Logger.error("Script task crashed: #{inspect(reason)}", task_id: state.task_id)
          {:noreply, %{state | script_task_ref: nil, script_task_pid: nil}}
      end
    end
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, reason}, %{executor_monitor_ref: ref} = state) when ref != nil do
    cancel_executor_timeout(state.executor_timeout_ref)

    if state.stopping do
      {:noreply, %{state | executor_monitor_ref: nil, executor_timeout_ref: nil}}
    else
      case reason do
        :normal ->
          {:noreply, %{state | executor_monitor_ref: nil, executor_timeout_ref: nil}}

        _ ->
          Logger.error("Executor process died unexpectedly: #{inspect(reason)}",
            task_id: state.task_id
          )

          handle_executor_crash(state, reason)
      end
    end
  end

  @impl true
  def handle_info(:executor_timeout, state) do
    if state.stopping do
      {:noreply, state}
    else
      if state.awaiting_external_executor do
        Logger.error("Executor timeout after #{div(@executor_timeout_ms, 60_000)} minutes",
          task_id: state.task_id
        )

        handle_executor_crash(state, :timeout)
      else
        {:noreply, state}
      end
    end
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # ============================================================================
  # Hook Execution
  # ============================================================================

  defp run_hook(state, execution) do
    case get_hook_and_column_hook(execution) do
      {:ok, column_hook, hook} ->
        execute_hook_impl(state, execution, column_hook, hook)

      {:error, reason} ->
        Logger.error("Could not find hook for execution #{execution.id}: #{inspect(reason)}")
        handle_hook_failure(state, execution, "Hook not found")
    end
  end

  defp execute_hook_impl(state, execution, column_hook, hook) do
    case Task.get(state.task_id) do
      {:ok, task} ->
        if !column_hook.transparent do
          set_task_executing(task, hook.name)
        end

        hook_opts = [
          board_id: state.board_id,
          hook_settings: execution.hook_settings || %{},
          execution: execution
        ]

        if hook.hook_kind == :script do
          run_script_async(state, execution, column_hook, hook, task, hook_opts)
        else
          run_hook_sync(state, execution, column_hook, hook, task, hook_opts)
        end

      {:error, _} ->
        Logger.error("Task #{state.task_id} not found")
        handle_hook_failure(state, execution, "Task not found")
    end
  end

  defp run_script_async(state, execution, column_hook, hook, task, hook_opts) do
    parent = self()
    exec_id = execution.id
    ch_id = column_hook.id
    callers = CallerTracking.capture_callers()

    {pid, ref} =
      spawn_monitor(fn ->
        CallerTracking.restore_callers(callers)
        result = HookRunner.execute(hook, task, nil, hook_opts)
        send(parent, {:script_result, exec_id, ch_id, result})
      end)

    {:noreply, %{state | script_task_pid: pid, script_task_ref: ref}}
  end

  defp run_hook_sync(state, execution, column_hook, hook, task, hook_opts) do
    case HookRunner.execute(hook, task, nil, hook_opts) do
      {:ok, _result} ->
        handle_hook_success(state, execution, column_hook)

      {:await_executor, _task_id} ->
        Logger.info("Awaiting external executor", task_id: state.task_id)
        monitor_ref = monitor_executor(state.task_id)
        timeout_ref = Process.send_after(self(), :executor_timeout, @executor_timeout_ms)

        new_state = %{
          state
          | awaiting_external_executor: true,
            executor_monitor_ref: monitor_ref,
            executor_timeout_ref: timeout_ref
        }

        {:noreply, new_state}

      {:error, reason} ->
        handle_hook_error(state, execution, column_hook, hook, reason)
    end
  end

  defp monitor_executor(task_id) do
    case Runner.lookup_by_task(task_id) do
      {:ok, pid} ->
        Logger.debug("Monitoring executor process for task #{task_id}")
        Process.monitor(pid)

      {:error, :not_found} ->
        Logger.warning("Executor process not found for task #{task_id}, cannot monitor")
        nil
    end
  end

  defp handle_script_result(state, exec_id, column_hook_id, result) do
    case HookExecution.get(exec_id) do
      {:ok, execution} ->
        column_hook = get_column_hook(%{column_hook_id: column_hook_id})
        hook = get_hook_from_execution(execution)

        state = %{state | script_task_ref: nil, script_task_pid: nil}

        case result do
          {:ok, _output} ->
            handle_hook_success(state, execution, column_hook)

          {:error, reason} ->
            if column_hook && hook do
              handle_hook_error(state, execution, column_hook, hook, reason)
            else
              handle_hook_failure(state, execution, "Hook execution failed: #{inspect(reason)}")
            end
        end

      {:error, _} ->
        Logger.error("Execution #{exec_id} not found for script result")

        new_state = %{state | current_execution_id: nil, script_task_ref: nil, script_task_pid: nil}

        {:noreply, new_state}
    end
  end

  defp get_hook_from_execution(execution) do
    case get_hook(execution.hook_id) do
      {:ok, hook} -> hook
      _ -> nil
    end
  end

  defp handle_hook_success(state, execution, column_hook) do
    mark_hook_executed_if_needed(column_hook, state.task_id)
    complete_execution_with_retry(execution, 3)

    if !column_hook.transparent do
      clear_task_executing(state.task_id)
    end

    TaskServer.hook_completed(state.task_id, execution.id, :ok)
    {:noreply, %{state | current_execution_id: nil}}
  end

  defp complete_execution_with_retry(execution, retries) when retries > 0 do
    case HookExecution.complete(execution) do
      {:ok, _updated_execution} ->
        :ok

      {:error, reason} ->
        Logger.warning("Failed to complete execution #{execution.id} (#{retries} retries left): #{inspect(reason)}")

        Process.sleep(100)
        complete_execution_with_retry(execution, retries - 1)
    end
  end

  defp complete_execution_with_retry(execution, 0) do
    Logger.error("Failed to complete execution #{execution.id} after all retries - execution state may be inconsistent")

    :error
  end

  defp handle_hook_error(state, execution, column_hook, hook, reason) do
    error_message = format_error_message(hook.name, reason)

    if column_hook.transparent do
      Logger.warning("Transparent hook '#{hook.name}' failed: #{error_message}")
      fail_execution_with_retry(execution, error_message, 3)

      TaskServer.hook_completed(state.task_id, execution.id, {:error, reason})
      {:noreply, %{state | current_execution_id: nil}}
    else
      set_task_error(state.task_id, hook.name, reason)
      fail_execution_with_retry(execution, error_message, 3)

      cancel_remaining_hooks(state.task_id, :error)
      clear_task_executing(state.task_id)

      TaskServer.hook_completed(state.task_id, execution.id, {:error, reason})
      {:noreply, %{state | current_execution_id: nil}}
    end
  end

  defp fail_execution_with_retry(execution, error_message, retries) when retries > 0 do
    case HookExecution.fail(execution, %{error_message: error_message}) do
      {:ok, _updated_execution} ->
        :ok

      {:error, reason} ->
        Logger.warning("Failed to fail execution #{execution.id} (#{retries} retries left): #{inspect(reason)}")

        Process.sleep(100)
        fail_execution_with_retry(execution, error_message, retries - 1)
    end
  end

  defp fail_execution_with_retry(execution, _error_message, 0) do
    Logger.error("Failed to fail execution #{execution.id} after all retries - execution state may be inconsistent")

    :error
  end

  defp handle_hook_failure(state, execution, error_message) do
    fail_execution_with_retry(execution, error_message, 3)
    TaskServer.hook_completed(state.task_id, execution.id, {:error, error_message})
    {:noreply, %{state | current_execution_id: nil}}
  end

  # ============================================================================
  # External Executor Handling
  # ============================================================================

  defp handle_external_executor_completion(state, exit_code, error_message) do
    demonitor_executor(state.executor_monitor_ref)
    cancel_executor_timeout(state.executor_timeout_ref)

    if state.current_execution_id do
      case HookExecution.get(state.current_execution_id) do
        {:ok, execution} ->
          if exit_code == 0 do
            column_hook = get_column_hook(execution)

            if column_hook do
              mark_hook_executed_if_needed(column_hook, state.task_id)
            end

            HookExecution.complete(execution)
            clear_task_executing(state.task_id)
            TaskServer.hook_completed(state.task_id, execution.id, :ok)

            {:noreply,
             %{
               state
               | current_execution_id: nil,
                 awaiting_external_executor: false,
                 executor_monitor_ref: nil,
                 executor_timeout_ref: nil
             }}
          else
            column_hook = get_column_hook(execution)
            hook = get_hook_from_execution(execution)

            reason =
              if error_message do
                error_message
              else
                {:exit_code, exit_code, ""}
              end

            if column_hook && hook do
              {reply, new_state} = handle_hook_error(state, execution, column_hook, hook, reason)

              {reply,
               %{new_state | awaiting_external_executor: false, executor_monitor_ref: nil, executor_timeout_ref: nil}}
            else
              error_msg = format_error_for_display(exit_code, error_message)
              HookExecution.fail(execution, %{error_message: error_msg})
              clear_task_executing(state.task_id)
              TaskServer.hook_completed(state.task_id, execution.id, {:error, error_msg})

              {:noreply,
               %{
                 state
                 | current_execution_id: nil,
                   awaiting_external_executor: false,
                   executor_monitor_ref: nil,
                   executor_timeout_ref: nil
               }}
            end
          end

        {:error, _} ->
          Logger.error("Could not find execution #{state.current_execution_id}")

          {:noreply,
           %{
             state
             | current_execution_id: nil,
               awaiting_external_executor: false,
               executor_monitor_ref: nil,
               executor_timeout_ref: nil
           }}
      end
    else
      {:noreply, %{state | awaiting_external_executor: false, executor_monitor_ref: nil, executor_timeout_ref: nil}}
    end
  end

  defp demonitor_executor(nil), do: :ok
  defp demonitor_executor(ref), do: Process.demonitor(ref, [:flush])

  defp cancel_executor_timeout(nil), do: :ok
  defp cancel_executor_timeout(ref), do: Process.cancel_timer(ref)

  defp format_error_for_display(exit_code, nil), do: "Executor failed with exit code #{exit_code}"
  defp format_error_for_display(exit_code, message), do: "Exit code #{exit_code}: #{message}"

  defp handle_executor_crash(state, reason) do
    error_message = "Executor process crashed: #{format_crash_reason(reason)}"

    if state.current_execution_id do
      case HookExecution.get(state.current_execution_id) do
        {:ok, execution} ->
          HookExecution.fail(execution, %{error_message: error_message})
          cancel_remaining_hooks(state.task_id, :error)

        {:error, _} ->
          Logger.warning("Could not find execution #{state.current_execution_id} to fail")
      end
    end

    set_task_error(state.task_id, "AI Executor", error_message)
    move_task_to_review(state)

    new_state = %{
      state
      | current_execution_id: nil,
        awaiting_external_executor: false,
        executor_monitor_ref: nil,
        executor_timeout_ref: nil
    }

    TaskServer.hook_completed(state.task_id, state.current_execution_id, {:error, error_message})
    {:noreply, new_state}
  end

  defp format_crash_reason(:noproc), do: "process not found"
  defp format_crash_reason(:noconnection), do: "connection lost"
  defp format_crash_reason(:killed), do: "process was killed"
  defp format_crash_reason({:shutdown, reason}), do: "shutdown: #{inspect(reason)}"
  defp format_crash_reason(reason), do: inspect(reason)

  defp move_task_to_review(state) do
    case ColumnLookup.find_column_by_name(state.board_id, "To Review") do
      {:ok, to_review_column_id} ->
        case Task.get(state.task_id) do
          {:ok, task} when task.column_id != to_review_column_id ->
            case Task.move(task, %{column_id: to_review_column_id}) do
              {:ok, updated_task} ->
                Logger.info("Moved task #{state.task_id} to 'To Review' column after executor crash")

                PubSub.broadcast(
                  Viban.PubSub,
                  "board:#{state.board_id}",
                  {:task_changed, %{task: updated_task, action: :move}}
                )

              {:error, reason} ->
                Logger.warning("Failed to move task to 'To Review': #{inspect(reason)}")
            end

          {:ok, _task} ->
            Logger.debug("Task #{state.task_id} already in 'To Review' column")

          {:error, _} ->
            Logger.warning("Task #{state.task_id} not found when trying to move to 'To Review'")
        end

      {:error, _} ->
        Logger.warning("'To Review' column not found in board #{state.board_id}")
    end
  end

  defp stop_external_executor(task_id) do
    case Runner.stop_by_task(task_id, :user_cancelled) do
      :ok -> Logger.info("Stopped external executor for task #{task_id}")
      {:error, :not_running} -> :ok
      {:error, err} -> Logger.warning("Failed to stop executor: #{inspect(err)}")
    end
  end

  defp kill_script_task(%{script_task_pid: pid, script_task_ref: ref, task_id: task_id}) when is_pid(pid) do
    Logger.info("Killing script task", task_id: task_id)
    Process.demonitor(ref, [:flush])
    Process.exit(pid, :kill)
  end

  defp kill_script_task(_state), do: :ok

  defp cancel_current_execution(%{current_execution_id: nil}), do: :ok

  defp cancel_current_execution(%{current_execution_id: exec_id, task_id: task_id}) do
    case HookExecution.get(exec_id) do
      {:ok, execution} ->
        HookExecution.cancel(execution, %{skip_reason: :user_cancelled})
        Logger.info("Cancelled execution #{exec_id}")

      {:error, _} ->
        :ok
    end

    clear_task_executing(task_id)
  end

  # ============================================================================
  # Hook Helpers
  # ============================================================================

  defp get_hook_and_column_hook(execution) do
    column_hook = get_column_hook(execution)

    if column_hook do
      case get_hook(column_hook.hook_id) do
        {:ok, hook} -> {:ok, column_hook, hook}
        error -> error
      end
    else
      {:error, :column_hook_not_found}
    end
  end

  defp get_column_hook(%{column_hook_id: nil}), do: nil

  defp get_column_hook(%{column_hook_id: id}) do
    case ColumnHook.get(id) do
      {:ok, ch} -> ch
      _ -> nil
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

  defp mark_hook_executed_if_needed(nil, _task_id), do: :ok

  defp mark_hook_executed_if_needed(column_hook, task_id) do
    if column_hook.execute_once do
      case Task.get(task_id) do
        {:ok, task} -> Task.mark_hook_executed(task, column_hook.id)
        _ -> :ok
      end
    end
  end

  defp cancel_remaining_hooks(task_id, skip_reason) do
    case HookExecution.pending_for_task(task_id) do
      {:ok, pending} ->
        Enum.each(pending, fn exec ->
          column_hook = get_column_hook(exec)

          should_skip =
            case skip_reason do
              :error ->
                !column_hook || !column_hook.transparent

              _ ->
                true
            end

          if should_skip do
            case HookExecution.skip(exec, %{skip_reason: skip_reason}) do
              {:ok, _updated_exec} ->
                :ok

              {:error, _} ->
                :ok
            end
          end
        end)

      {:error, _} ->
        :ok
    end
  end

  # ============================================================================
  # Task Status
  # ============================================================================

  defp set_task_executing(task, hook_name) do
    Task.update_agent_status(task, %{
      agent_status: :executing,
      agent_status_message: "Executing #{hook_name}"
    })

    Task.set_in_progress(task, %{in_progress: true})
  end

  defp clear_task_executing(task_id) do
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

  defp set_task_error(task_id, hook_name, reason) do
    error_message = format_error_message(hook_name, reason)
    Logger.error("Task #{task_id} hook '#{hook_name}' failed: #{error_message}")

    case Task.get(task_id) do
      {:ok, task} ->
        Task.set_error(task, %{
          agent_status: :error,
          error_message: error_message,
          in_progress: false
        })

      _ ->
        :ok
    end
  end

  # ============================================================================
  # Error Formatting
  # ============================================================================

  defp format_error_message(hook_name, {:exit_code, code, output}) do
    truncated = String.slice(output || "", 0, @max_error_output_length)
    "Hook '#{hook_name}' failed with exit code #{code}: #{truncated}"
  end

  defp format_error_message(hook_name, :timeout), do: "Hook '#{hook_name}' timed out"

  defp format_error_message(hook_name, reason), do: "Hook '#{hook_name}' failed: #{inspect(reason)}"
end
