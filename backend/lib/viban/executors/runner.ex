defmodule Viban.Executors.Runner do
  @moduledoc """
  GenServer that manages the lifecycle of an executor subprocess.

  This module handles:
  - Spawning the executor process (CLI tools like Claude Code, Gemini, etc.)
  - Streaming stdout/stderr to subscribers (Phoenix Channels)
  - Process termination and cleanup
  - Storing logs for later review

  ## Architecture

  Each runner is started via DynamicSupervisor and manages a single executor
  subprocess. The runner uses Erlang ports to communicate with the subprocess
  and broadcasts events to the associated Phoenix Channel topic.

  ## Registry

  Runners register themselves in the `Viban.Executors.RunnerRegistry`, which
  allows looking up a runner by task_id. This is used for stopping executors
  when tasks are moved out of the "In Progress" column.

  ## Lifecycle

  1. Runner starts and creates an `ExecutorSession` in the database
  2. Executor process is spawned via Erlang port
  3. Output is streamed and broadcast to Phoenix Channel subscribers
  4. On completion/failure, session and task status are updated
  5. Runner process terminates

  ## Usage

      # Start via DynamicSupervisor
      {:ok, pid} = Viban.Executors.Runner.start(
        task_id: "uuid",
        executor_type: :claude_code,
        prompt: "Fix the bug",
        working_directory: "/path/to/worktree"
      )

      # Find runner by task_id
      {:ok, pid} = Viban.Executors.Runner.lookup_by_task(task_id)

      # Stop executor for a task
      :ok = Viban.Executors.Runner.stop_by_task(task_id, :column_moved)
  """

  use GenServer

  alias Viban.Executors.{Registry, ExecutorSession, ExecutorMessage, ImageHandler}
  alias Viban.GitHub.PRDetector
  alias VibanWeb.Endpoint

  require Logger

  # ---------------------------------------------------------------------------
  # Constants
  # ---------------------------------------------------------------------------

  @runner_registry Viban.Executors.RunnerRegistry

  @log_prefix "[ExecutorRunner]"

  # ---------------------------------------------------------------------------
  # Type Definitions
  # ---------------------------------------------------------------------------

  @type status :: :starting | :running | :completed | :failed | :stopped

  @type stop_reason ::
          :normal
          | :column_moved
          | :user_cancelled
          | :task_terminated
          | atom()

  @type t :: %__MODULE__{
          task_id: Ecto.UUID.t(),
          session_id: Ecto.UUID.t() | nil,
          executor_type: atom(),
          executor_module: module() | nil,
          prompt: String.t(),
          working_directory: String.t() | nil,
          port: port() | nil,
          status: status(),
          started_at: DateTime.t() | nil,
          output_buffer: [{DateTime.t(), String.t()}],
          exit_code: integer() | nil,
          image_paths: [String.t()]
        }

  defstruct [
    :task_id,
    :session_id,
    :executor_type,
    :executor_module,
    :prompt,
    :working_directory,
    :port,
    :status,
    :started_at,
    :output_buffer,
    :exit_code,
    :image_paths
  ]

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Start an executor runner under the DynamicSupervisor.

  ## Options

  - `:task_id` - Required. The task UUID to associate with this runner
  - `:executor_type` - Required. The type of executor (e.g., `:claude_code`)
  - `:prompt` - Required. The prompt/instruction for the executor
  - `:working_directory` - Optional. Working directory for the executor
  - `:images` - Optional. List of image attachments

  ## Returns

  - `{:ok, pid}` - Runner started successfully
  - `{:error, reason}` - Failed to start runner
  """
  @spec start(keyword()) :: {:ok, pid()} | {:error, term()}
  def start(opts) do
    DynamicSupervisor.start_child(
      Viban.Executors.RunnerSupervisor,
      {__MODULE__, opts}
    )
  end

  @doc """
  Stop a running executor.

  ## Parameters

  - `pid` - The runner process PID
  - `reason` - Optional stop reason (default: `:normal`)

  ## Returns

  - `:ok` - Always returns `:ok`
  """
  @spec stop(pid(), stop_reason()) :: :ok
  def stop(pid, reason \\ :normal) do
    GenServer.call(pid, {:stop, reason})
  end

  @doc """
  Look up a runner by task_id.

  ## Returns

  - `{:ok, pid}` - Runner found
  - `{:error, :not_found}` - No runner for this task
  """
  @spec lookup_by_task(Ecto.UUID.t()) :: {:ok, pid()} | {:error, :not_found}
  def lookup_by_task(task_id) do
    case Elixir.Registry.lookup(@runner_registry, task_id) do
      [{pid, _}] -> {:ok, pid}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Stop an executor by task_id.

  ## Returns

  - `:ok` - Executor stopped
  - `{:error, :not_running}` - No executor running for this task
  """
  @spec stop_by_task(Ecto.UUID.t(), stop_reason()) :: :ok | {:error, :not_running}
  def stop_by_task(task_id, reason \\ :normal) do
    case lookup_by_task(task_id) do
      {:ok, pid} -> stop(pid, reason)
      {:error, :not_found} -> {:error, :not_running}
    end
  end

  @doc """
  Get the current status of an executor.

  ## Returns

  A map with `:status` and `:exit_code` keys.
  """
  @spec status(pid()) :: %{status: status(), exit_code: integer() | nil}
  def status(pid) do
    GenServer.call(pid, :status)
  end

  @doc """
  Send input to the executor's stdin (for interactive executors).

  ## Returns

  - `:ok` - Input sent successfully
  - `{:error, :not_running}` - Executor is not running
  """
  @spec send_input(pid(), String.t()) :: :ok | {:error, :not_running}
  def send_input(pid, input) do
    GenServer.call(pid, {:send_input, input})
  end

  # ---------------------------------------------------------------------------
  # GenServer Callbacks
  # ---------------------------------------------------------------------------

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

  @impl true
  def init(opts) do
    task_id = Keyword.fetch!(opts, :task_id)
    executor_type = Keyword.fetch!(opts, :executor_type)
    prompt = Keyword.fetch!(opts, :prompt)
    working_directory = Keyword.get(opts, :working_directory)
    images = Keyword.get(opts, :images, [])

    case Registry.get_by_type(executor_type) do
      nil ->
        {:stop, {:error, :unknown_executor_type}}

      executor_module ->
        init_with_executor(
          executor_module,
          task_id,
          executor_type,
          prompt,
          working_directory,
          images
        )
    end
  end

  @impl true
  def handle_info(:start_executor, state) do
    %{
      executor_module: executor_module,
      prompt: prompt,
      working_directory: working_directory,
      task_id: task_id,
      session_id: session_id,
      image_paths: image_paths
    } = state

    enhanced_prompt = ImageHandler.build_prompt_with_images(prompt, image_paths || [])

    executor_opts =
      executor_module.default_opts()
      |> Keyword.merge(working_directory: working_directory)

    {executable, args} = executor_module.build_command(enhanced_prompt, executor_opts)

    Logger.info(
      "#{@log_prefix} Starting #{executor_module.name()} for task #{task_id}: #{executable} #{Enum.join(args, " ")}"
    )

    port_opts = build_port_options(args, working_directory, executor_module)

    case find_executable(executable) do
      {:ok, path} ->
        port = Port.open({:spawn_executable, String.to_charlist(path)}, port_opts)
        broadcast_started(task_id, session_id, state.executor_type)
        {:noreply, %{state | port: port, status: :running}}

      {:error, error} ->
        Logger.error("#{@log_prefix} #{error}")
        broadcast_error(task_id, session_id, error)
        {:stop, {:error, :executable_not_found}, %{state | status: :failed}}
    end
  end

  @impl true
  def handle_info({port, {:data, data}}, %{port: port} = state) do
    %{
      task_id: task_id,
      session_id: session_id,
      executor_module: executor_module,
      output_buffer: buffer
    } = state

    Logger.debug("#{@log_prefix} Received data: #{String.slice(data, 0, 200)}")

    data
    |> String.split("\n", trim: true)
    |> Enum.each(&process_output_line(&1, executor_module, task_id, session_id))

    new_buffer = buffer ++ [{DateTime.utc_now(), data}]
    {:noreply, %{state | output_buffer: new_buffer}}
  end

  @impl true
  def handle_info({port, {:exit_status, exit_code}}, %{port: port} = state) do
    %{task_id: task_id, session_id: session_id} = state

    Logger.info("#{@log_prefix} Process exited with code #{exit_code} for task #{task_id}")

    status = if exit_code == 0, do: :completed, else: :failed
    broadcast_completed(task_id, session_id, exit_code, status)
    update_session_status(session_id, status, exit_code)
    update_task_status(task_id, status, exit_code)

    {:stop, :normal, %{state | status: status, exit_code: exit_code, port: nil}}
  end

  @impl true
  def handle_call(:status, _from, state) do
    {:reply, %{status: state.status, exit_code: state.exit_code}, state}
  end

  @impl true
  def handle_call({:stop, reason}, _from, state) do
    %{port: port, task_id: task_id, session_id: session_id} = state

    if port, do: Port.close(port)

    broadcast_stopped(task_id, session_id, reason)
    update_task_status(task_id, :stopped, nil, reason)

    {:stop, reason, :ok, %{state | status: :stopped, port: nil}}
  end

  @impl true
  def handle_call({:send_input, input}, _from, %{port: port} = state) when not is_nil(port) do
    Port.command(port, input)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:send_input, _input}, _from, state) do
    {:reply, {:error, :not_running}, state}
  end

  @impl true
  def terminate(reason, %{port: port}) do
    if port, do: Port.close(port)
    Logger.debug("#{@log_prefix} Terminated with reason: #{inspect(reason)}")
    :ok
  end

  # ---------------------------------------------------------------------------
  # Private Functions - Initialization
  # ---------------------------------------------------------------------------

  defp via_tuple(task_id) do
    {:via, Elixir.Registry, {@runner_registry, task_id}}
  end

  defp init_with_executor(
         executor_module,
         task_id,
         executor_type,
         prompt,
         working_directory,
         images
       ) do
    unless executor_module.available?() do
      {:stop, {:error, :executor_not_available}}
    else
      image_paths = ImageHandler.save_to_directory(images, working_directory)

      case create_session(task_id, executor_type, prompt, working_directory) do
        {:ok, session} ->
          display_prompt = ImageHandler.build_display_prompt(prompt, image_paths)
          save_message(session.id, :user, display_prompt)

          state = %__MODULE__{
            task_id: task_id,
            session_id: session.id,
            executor_type: executor_type,
            executor_module: executor_module,
            prompt: prompt,
            working_directory: working_directory,
            status: :starting,
            started_at: DateTime.utc_now(),
            output_buffer: [],
            image_paths: image_paths
          }

          send(self(), :start_executor)
          {:ok, state}

        {:error, error} ->
          Logger.error("#{@log_prefix} Failed to create session: #{inspect(error)}")
          {:stop, {:error, :failed_to_create_session}}
      end
    end
  end

  defp create_session(task_id, executor_type, prompt, working_directory) do
    ExecutorSession.create(%{
      task_id: task_id,
      executor_type: executor_type,
      prompt: prompt,
      working_directory: working_directory
    })
  end

  # ---------------------------------------------------------------------------
  # Private Functions - Port Management
  # ---------------------------------------------------------------------------

  defp build_port_options(args, working_directory, executor_module) do
    charlist_args = Enum.map(args, &String.to_charlist/1)

    opts = [
      :binary,
      :exit_status,
      :stderr_to_stdout,
      :stream,
      args: charlist_args
    ]

    opts =
      if working_directory do
        [{:cd, String.to_charlist(working_directory)} | opts]
      else
        opts
      end

    env = build_environment(executor_module)
    [{:env, env} | opts]
  end

  defp build_environment(executor_module) do
    if function_exported?(executor_module, :env, 0) do
      executor_module.env()
      |> Enum.map(fn {k, v} -> {String.to_charlist(k), String.to_charlist(v)} end)
    else
      []
    end
  end

  defp find_executable(executable) do
    path =
      if String.starts_with?(executable, "/") do
        if File.exists?(executable), do: executable, else: nil
      else
        System.find_executable(executable)
      end

    case path do
      nil -> {:error, "Executable not found: #{executable}"}
      p -> {:ok, p}
    end
  end

  # ---------------------------------------------------------------------------
  # Private Functions - Output Processing
  # ---------------------------------------------------------------------------

  defp process_output_line(line, executor_module, task_id, session_id) do
    parsed =
      if function_exported?(executor_module, :parse_output, 1) do
        executor_module.parse_output(line)
      else
        {:raw, line}
      end

    handle_parsed_output(parsed, task_id, session_id)
  end

  defp handle_parsed_output(
         {:ok, %{type: :assistant_message, content: content} = event},
         task_id,
         session_id
       ) do
    save_message(session_id, :assistant, content)
    broadcast_output(task_id, session_id, :parsed, event)
    PRDetector.process_output(task_id, content)
  end

  defp handle_parsed_output(
         {:ok, %{type: :todo_update, todos: todos} = event},
         task_id,
         session_id
       ) do
    broadcast_todos(task_id, session_id, todos)
    broadcast_output(task_id, session_id, :parsed, event)
  end

  defp handle_parsed_output({:ok, %{type: :tool_use} = event}, task_id, session_id) do
    tool_name = Map.get(event, :tool, "unknown")
    save_message(session_id, :tool, "Using tool: #{tool_name}", %{tool: tool_name})
    broadcast_output(task_id, session_id, :parsed, event)
  end

  defp handle_parsed_output(
         {:ok, %{type: :result, content: content} = event},
         task_id,
         session_id
       ) do
    broadcast_output(task_id, session_id, :parsed, event)
    PRDetector.process_output(task_id, content)
    update_task_agent_status(task_id, :waiting_for_user, "Waiting for user input")
  end

  defp handle_parsed_output({:ok, event}, task_id, session_id) do
    broadcast_output(task_id, session_id, :parsed, event)
  end

  defp handle_parsed_output({:raw, raw_data}, task_id, session_id) do
    broadcast_output(task_id, session_id, :raw, raw_data)
    PRDetector.process_output(task_id, raw_data)
  end

  # ---------------------------------------------------------------------------
  # Private Functions - Broadcasting
  # ---------------------------------------------------------------------------

  defp broadcast_started(task_id, session_id, executor_type) do
    Endpoint.broadcast!("task:#{task_id}", "executor_started", %{
      session_id: session_id,
      executor_type: executor_type,
      started_at: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end

  defp broadcast_output(task_id, session_id, type, content) do
    Endpoint.broadcast!("task:#{task_id}", "executor_output", %{
      session_id: session_id,
      type: type,
      content: content,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end

  defp broadcast_todos(task_id, session_id, todos) do
    Endpoint.broadcast!("task:#{task_id}", "executor_todos", %{
      session_id: session_id,
      todos: todos,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end

  defp broadcast_completed(task_id, session_id, exit_code, status) do
    Endpoint.broadcast!("task:#{task_id}", "executor_completed", %{
      session_id: session_id,
      exit_code: exit_code,
      status: status,
      completed_at: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end

  defp broadcast_stopped(task_id, session_id, reason) do
    Endpoint.broadcast!("task:#{task_id}", "executor_stopped", %{
      session_id: session_id,
      reason: reason_to_string(reason),
      stopped_at: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end

  defp broadcast_error(task_id, session_id, error) do
    Endpoint.broadcast!("task:#{task_id}", "executor_error", %{
      session_id: session_id,
      error: error,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end

  defp reason_to_string(:column_moved), do: "Task moved out of In Progress column"
  defp reason_to_string(:user_cancelled), do: "Cancelled by user"
  defp reason_to_string(:task_terminated), do: "Task was deleted"
  defp reason_to_string(:normal), do: "Stopped by user"
  defp reason_to_string(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp reason_to_string(reason), do: inspect(reason)

  # ---------------------------------------------------------------------------
  # Private Functions - Database Operations
  # ---------------------------------------------------------------------------

  defp save_message(session_id, role, content, metadata \\ %{}) do
    case ExecutorMessage.create(%{
           session_id: session_id,
           role: role,
           content: content,
           metadata: metadata
         }) do
      {:ok, _message} ->
        :ok

      {:error, error} ->
        Logger.warning("#{@log_prefix} Failed to save message: #{inspect(error)}")
        :error
    end
  end

  defp update_session_status(session_id, status, exit_code) do
    case ExecutorSession.get(session_id) do
      {:ok, session} ->
        action = status_to_session_action(status)
        params = if exit_code, do: %{exit_code: exit_code}, else: %{}

        case apply(ExecutorSession, action, [session, params]) do
          {:ok, _} ->
            :ok

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

  defp update_task_status(task_id, status, exit_code, _stop_reason \\ nil) do
    executor_done = status in [:completed, :failed]

    if executor_done do
      handle_executor_completion(task_id, exit_code)
    end
  end

  defp handle_executor_completion(task_id, exit_code) do
    Phoenix.PubSub.broadcast(
      Viban.PubSub,
      "executor:#{task_id}:completed",
      {:executor_completed, exit_code}
    )
  end

  defp update_task_agent_status(task_id, status, message) do
    alias Viban.Kanban.Task

    case Task.get(task_id) do
      {:ok, task} ->
        case Task.update_agent_status(task, %{
               agent_status: status,
               agent_status_message: message
             }) do
          {:ok, _} ->
            Logger.debug("#{@log_prefix} Updated task #{task_id} status to #{status}")
            :ok

          {:error, error} ->
            Logger.warning("#{@log_prefix} Failed to update task status: #{inspect(error)}")
            :error
        end

      {:error, _} ->
        Logger.warning("#{@log_prefix} Task not found: #{task_id}")
        :error
    end
  end
end
