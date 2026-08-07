defmodule Viban.Executors.ApiRunner do
  @moduledoc """
  GenServer managing the lifecycle of an API-based executor (Jido AI).

  Unlike the CLI-based Runner which uses Erlang ports, the ApiRunner
  starts a Jido.AI.Agent server and uses ask_sync to process prompts
  with tool use via the ReAct strategy.

  Follows the same lifecycle pattern as Runner:
  1. Creates an ExecutorSession in the database
  2. Runs the Jido AI agent with tools from AshJido
  3. Saves output as ExecutorMessages and broadcasts via PubSub
  4. Updates session and task status on completion
  """

  use GenServer

  alias Viban.Executors.Registry
  alias Viban.Jido.Agents.AITaskAgent
  alias Viban.Kanban.ExecutorMessage
  alias Viban.Kanban.ExecutorSession
  alias Viban.Kanban.TaskActivityNotifier

  require Logger

  @runner_registry Viban.Executors.RunnerRegistry
  @log_prefix "[ApiRunner]"

  defstruct [
    :task_id,
    :session_id,
    :executor_type,
    :executor_module,
    :prompt,
    :working_directory,
    :api_config,
    :agent_pid,
    :status,
    :started_at,
    :runner_task,
    :exit_code,
    :last_error
  ]

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @spec start(keyword()) :: {:ok, pid()} | {:error, term()}
  def start(opts) do
    DynamicSupervisor.start_child(
      Viban.Executors.RunnerSupervisor,
      {__MODULE__, opts}
    )
  end

  def start_link(opts) do
    task_id = Keyword.fetch!(opts, :task_id)
    GenServer.start_link(__MODULE__, opts, name: via_tuple(task_id))
  end

  def child_spec(opts) do
    %{
      id: {__MODULE__, Keyword.fetch!(opts, :task_id)},
      start: {__MODULE__, :start_link, [opts]},
      restart: :temporary
    }
  end

  # ---------------------------------------------------------------------------
  # GenServer Callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(opts) do
    task_id = Keyword.fetch!(opts, :task_id)
    executor_type = Keyword.fetch!(opts, :executor_type)
    prompt = Keyword.fetch!(opts, :prompt)
    working_directory = Keyword.get(opts, :working_directory)
    api_config = Keyword.fetch!(opts, :api_config)

    case Registry.get_by_type(executor_type) do
      nil ->
        {:stop, {:error, :unknown_executor_type}}

      executor_module ->
        if executor_module.available?() do
          init_with_config(executor_module, task_id, executor_type, prompt, working_directory, api_config)
        else
          {:stop, {:error, :executor_not_available}}
        end
    end
  end

  @impl true
  def handle_info(:run_agent, state) do
    runner_task =
      Task.async(fn ->
        run_jido_agent(state)
      end)

    {:noreply, %{state | runner_task: runner_task, status: :running}}
  end

  @impl true
  def handle_info({ref, result}, %{runner_task: %Task{ref: ref}} = state) do
    Process.demonitor(ref, [:flush])

    case result do
      {:ok, response} when is_binary(response) ->
        save_message(state.task_id, state.session_id, :assistant, response)
        finalize(state, 0, nil)

      {:ok, %{text: text}} ->
        save_message(state.task_id, state.session_id, :assistant, text)
        finalize(state, 0, nil)

      {:ok, response} ->
        save_message(state.task_id, state.session_id, :assistant, inspect(response))
        finalize(state, 0, nil)

      {:error, reason} ->
        error_msg = inspect(reason)
        save_message(state.task_id, state.session_id, :system, "Error: #{error_msg}")
        finalize(state, 1, error_msg)
    end
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, reason}, %{runner_task: %Task{ref: ref}} = state) do
    error_msg = inspect(reason)
    Logger.error("#{@log_prefix} Agent task crashed: #{error_msg}")
    save_message(state.task_id, state.session_id, :system, "Agent crashed: #{error_msg}")
    finalize(state, 1, error_msg)
  end

  @impl true
  def handle_call({:stop, reason}, _from, state) do
    cleanup_agent(state)

    if state.runner_task do
      Task.shutdown(state.runner_task, :brutal_kill)
    end

    save_message(state.task_id, state.session_id, :system, "Stopped: #{inspect(reason)}")
    update_session_status(state.session_id, :stopped, nil, inspect(reason))
    update_task_on_completion(state.task_id, :stopped, nil, inspect(reason))

    {:stop, reason, :ok, %{state | status: :stopped, runner_task: nil, agent_pid: nil}}
  end

  @impl true
  def handle_call(:status, _from, state) do
    {:reply, %{status: state.status, exit_code: state.exit_code}, state}
  end

  @impl true
  def terminate(_reason, %{runner_task: task} = state) do
    if task, do: Task.shutdown(task, :brutal_kill)
    cleanup_agent(state)
    :ok
  end

  # ---------------------------------------------------------------------------
  # Private Functions
  # ---------------------------------------------------------------------------

  defp via_tuple(task_id) do
    {:via, Elixir.Registry, {@runner_registry, task_id}}
  end

  defp init_with_config(executor_module, task_id, executor_type, prompt, working_directory, api_config) do
    case create_session(task_id, executor_type, prompt, working_directory) do
      {:ok, session} ->
        state = %__MODULE__{
          task_id: task_id,
          session_id: session.id,
          executor_type: executor_type,
          executor_module: executor_module,
          prompt: prompt,
          working_directory: working_directory,
          api_config: api_config,
          status: :starting,
          started_at: DateTime.utc_now()
        }

        send(self(), :run_agent)
        {:ok, state}

      {:error, error} ->
        Logger.error("#{@log_prefix} Failed to create session: #{inspect(error)}")
        {:stop, {:error, :failed_to_create_session}}
    end
  end

  defp run_jido_agent(state) do
    save_message(state.task_id, state.session_id, :system, "Starting Jido AI agent...")

    all_tools = AITaskAgent.all_tools()

    case Jido.AgentServer.start(agent: AITaskAgent, jido: Viban.Jido) do
      {:ok, pid} ->
        result =
          AITaskAgent.ask_sync(pid, state.prompt,
            tools: all_tools,
            timeout: 300_000
          )

        safely_stop_agent(pid)
        result

      {:error, reason} ->
        {:error, {:agent_start_failed, reason}}
    end
  rescue
    e ->
      {:error, Exception.message(e)}
  end

  defp safely_stop_agent(pid) do
    if Process.alive?(pid) do
      try do
        GenServer.stop(pid, :normal, 5_000)
      catch
        :exit, _ -> :ok
      end
    end
  end

  defp cleanup_agent(%{agent_pid: pid}) when is_pid(pid) do
    safely_stop_agent(pid)
  end

  defp cleanup_agent(_state), do: :ok

  defp finalize(state, exit_code, error_message) do
    status = if exit_code == 0, do: :completed, else: :failed

    update_session_status(state.session_id, status, exit_code, error_message)
    update_task_on_completion(state.task_id, status, exit_code, error_message)
    handle_executor_completion(state.task_id, exit_code, error_message)

    {:stop, :normal, %{state | status: status, exit_code: exit_code, runner_task: nil}}
  end

  defp create_session(task_id, executor_type, prompt, working_directory) do
    ExecutorSession.create(%{
      task_id: task_id,
      executor_type: executor_type,
      prompt: prompt,
      working_directory: working_directory
    })
  end

  defp save_message(task_id, session_id, role, content, metadata \\ %{}) do
    case ExecutorMessage.create(%{
           task_id: task_id,
           session_id: session_id,
           role: role,
           content: content,
           metadata: metadata
         }) do
      {:ok, message} ->
        TaskActivityNotifier.broadcast_executor_message(task_id, message)
        :ok

      {:error, error} ->
        Logger.warning("#{@log_prefix} Failed to save message: #{inspect(error)}")
        :error
    end
  end

  defp update_session_status(session_id, status, exit_code, error_message) do
    case ExecutorSession.get(session_id) do
      {:ok, session} ->
        action = status_to_session_action(status)

        params =
          %{}
          |> maybe_put(:exit_code, exit_code)
          |> maybe_put(:error_message, error_message)

        case apply(ExecutorSession, action, [session, params]) do
          {:ok, updated_session} ->
            TaskActivityNotifier.broadcast_session_update(session.task_id, updated_session)

          {:error, error} ->
            Logger.warning("#{@log_prefix} Failed to update session: #{inspect(error)}")
        end

      {:error, _} ->
        Logger.warning("#{@log_prefix} Session not found: #{session_id}")
    end
  end

  defp status_to_session_action(:completed), do: :complete
  defp status_to_session_action(:failed), do: :fail
  defp status_to_session_action(:stopped), do: :stop

  defp update_task_on_completion(task_id, status, exit_code, error_message) do
    alias Viban.Kanban.Task

    executor_done = status in [:completed, :failed]

    if executor_done do
      agent_status = if status == :completed, do: :idle, else: :error

      agent_message =
        case {status, error_message} do
          {:completed, _} -> nil
          {:failed, msg} when is_binary(msg) and msg != "" -> msg
          {:failed, _} -> "Failed with exit code #{exit_code}"
        end

      case Task.get(task_id) do
        {:ok, task} ->
          Task.update_agent_status(task, %{agent_status: agent_status, agent_status_message: agent_message})
          Task.set_in_progress(task, %{in_progress: false})

        {:error, _} ->
          Logger.warning("#{@log_prefix} Task not found: #{task_id}")
      end
    end
  end

  defp handle_executor_completion(task_id, exit_code, error_message) do
    Phoenix.PubSub.broadcast(
      Viban.PubSub,
      "executor:#{task_id}:completed",
      {:executor_completed, exit_code, error_message}
    )
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
