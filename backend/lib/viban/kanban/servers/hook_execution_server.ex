defmodule Viban.Kanban.Servers.HookExecutionServer do
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
  use GenServer
  require Logger

  alias Viban.Kanban.{ColumnHook, Hook, HookExecution, Task}
  alias Viban.Kanban.Actors.HookRunner
  alias Viban.Kanban.Servers.TaskServer
  alias Viban.Executors.Runner
  alias Phoenix.PubSub

  @pubsub Viban.PubSub
  @max_error_output_length 200

  @type state :: %__MODULE__{
          task_id: String.t(),
          board_id: String.t(),
          current_execution_id: String.t() | nil,
          awaiting_external_executor: boolean(),
          script_task_ref: reference() | nil,
          script_task_pid: pid() | nil,
          stopping: boolean()
        }

  defstruct [
    :task_id,
    :board_id,
    :current_execution_id,
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
    GenServer.start_link(__MODULE__, args, name: via_tuple(args.task_id))
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
    try do
      GenServer.call(pid, :stop, 30_000)
    catch
      :exit, {:noproc, _} -> :ok
      :exit, {:normal, _} -> :ok
    end
  end

  # ============================================================================
  # Server Callbacks
  # ============================================================================

  @impl true
  def init(args) do
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
  def handle_info({:executor_completed, exit_code}, state) do
    Logger.info("External executor completed with exit code #{exit_code}", task_id: state.task_id)

    if state.stopping do
      {:noreply, state}
    else
      handle_external_executor_completion(state, exit_code)
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
        unless column_hook.transparent do
          set_task_executing(task, hook.name)
        end

        hook_opts = [
          board_id: state.board_id,
          hook_settings: execution.hook_settings || %{}
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

    {pid, ref} =
      spawn_monitor(fn ->
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
        {:noreply, %{state | awaiting_external_executor: true}}

      {:error, reason} ->
        handle_hook_error(state, execution, column_hook, hook, reason)
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

        {:noreply,
         %{state | script_task_ref: nil, script_task_pid: nil, current_execution_id: nil}}
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

    case HookExecution.complete(execution) do
      {:ok, _} -> :ok
      {:error, reason} -> Logger.error("Failed to complete execution: #{inspect(reason)}")
    end

    unless column_hook.transparent do
      clear_task_executing(state.task_id)
    end

    TaskServer.hook_completed(state.task_id, execution.id, :ok)
    {:noreply, %{state | current_execution_id: nil}}
  end

  defp handle_hook_error(state, execution, column_hook, hook, reason) do
    error_message = format_error_message(hook.name, reason)

    if column_hook.transparent do
      Logger.warning("Transparent hook '#{hook.name}' failed: #{error_message}")

      case HookExecution.fail(execution, %{error_message: error_message}) do
        {:ok, _} -> :ok
        {:error, err} -> Logger.error("Failed to fail execution: #{inspect(err)}")
      end

      TaskServer.hook_completed(state.task_id, execution.id, {:error, reason})
      {:noreply, %{state | current_execution_id: nil}}
    else
      set_task_error(state.task_id, hook.name, reason)

      case HookExecution.fail(execution, %{error_message: error_message}) do
        {:ok, _} -> :ok
        {:error, err} -> Logger.error("Failed to fail execution: #{inspect(err)}")
      end

      cancel_remaining_hooks(state.task_id, :error)
      clear_task_executing(state.task_id)

      TaskServer.hook_completed(state.task_id, execution.id, {:error, reason})
      {:noreply, %{state | current_execution_id: nil}}
    end
  end

  defp handle_hook_failure(state, execution, error_message) do
    case HookExecution.fail(execution, %{error_message: error_message}) do
      {:ok, _} -> :ok
      {:error, reason} -> Logger.error("Failed to fail execution: #{inspect(reason)}")
    end

    TaskServer.hook_completed(state.task_id, execution.id, {:error, error_message})
    {:noreply, %{state | current_execution_id: nil}}
  end

  # ============================================================================
  # External Executor Handling
  # ============================================================================

  defp handle_external_executor_completion(state, exit_code) do
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
          else
            error_msg = "Executor failed with exit code #{exit_code}"
            HookExecution.fail(execution, %{error_message: error_msg})
            set_task_error(state.task_id, execution.hook_name, {:exit_code, exit_code, ""})
            cancel_remaining_hooks(state.task_id, :error)
            clear_task_executing(state.task_id)
            TaskServer.hook_completed(state.task_id, execution.id, {:error, error_msg})
          end

        {:error, _} ->
          Logger.error("Could not find execution #{state.current_execution_id}")
      end
    end

    {:noreply, %{state | current_execution_id: nil, awaiting_external_executor: false}}
  end

  defp stop_external_executor(task_id) do
    case Runner.stop_by_task(task_id, :user_cancelled) do
      :ok -> Logger.info("Stopped external executor for task #{task_id}")
      {:error, :not_running} -> :ok
      {:error, err} -> Logger.warning("Failed to stop executor: #{inspect(err)}")
    end
  end

  defp kill_script_task(%{script_task_pid: pid, script_task_ref: ref, task_id: task_id})
       when is_pid(pid) do
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
          HookExecution.skip(exec, %{skip_reason: skip_reason})
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

  defp format_error_message(hook_name, reason),
    do: "Hook '#{hook_name}' failed: #{inspect(reason)}"
end
