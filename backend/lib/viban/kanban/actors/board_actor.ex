defmodule Viban.Kanban.Actors.BoardActor do
  @moduledoc """
  Monitors tasks for a board and manages TaskActor lifecycle.

  ## Responsibilities

  - Subscribe to task changes for this board using Phoenix.PubSub
  - On task insert: spawn TaskActor
  - On task delete: terminate TaskActor (triggers cleanup)
  - On task update (column change): notify TaskActor

  ## State Management

  The actor caches column IDs to avoid repeated database queries:
  - `column_ids` - all column IDs for this board (for membership checks)

  These are refreshed on initialization and can be refreshed via `:refresh_columns`.

  ## PubSub Topics

  Subscribes to `task:updates` for task lifecycle events.

  ## Note on Auto-Move

  This actor does NOT automatically move tasks based on `in_progress` state.
  Task movement is handled by the TaskActor command queue, which queues
  a move_task command when the executor completes successfully.
  """
  use GenServer

  alias Viban.CallerTracking
  alias Viban.Kanban.Task.TaskSupervisor
  alias Viban.Kanban.Task

  require Logger

  # PubSub topic for task updates
  @task_updates_topic "task:updates"

  # Registry name
  @registry Viban.Kanban.ActorRegistry

  @type state :: %__MODULE__{
          board_id: String.t(),
          task_supervisor_name: GenServer.name(),
          column_ids: MapSet.t(String.t()),
          task_pids: %{String.t() => pid()}
        }

  defstruct [
    :board_id,
    :task_supervisor_name,
    column_ids: MapSet.new(),
    task_pids: %{}
  ]

  # ============================================================================
  # Client API
  # ============================================================================

  @doc """
  Starts the BoardActor for a specific board.
  """
  @spec start_link(String.t()) :: GenServer.on_start()
  def start_link(board_id) do
    callers = CallerTracking.capture_callers()
    GenServer.start_link(__MODULE__, {callers, board_id}, name: via_tuple(board_id))
  end

  @doc """
  Returns the via tuple for registry lookup.
  """
  @spec via_tuple(String.t()) :: {:via, Registry, {atom(), term()}}
  def via_tuple(board_id) do
    {:via, Registry, {@registry, {:board_actor, board_id}}}
  end

  @doc """
  Notifies the BoardActor that a task was created.
  """
  @spec notify_task_created(String.t(), Task.t()) :: :ok
  def notify_task_created(board_id, task) do
    with_board_actor(board_id, fn pid ->
      GenServer.call(pid, {:task_created, task})
    end)
  end

  @doc """
  Notifies the BoardActor that a task was updated.
  """
  @spec notify_task_updated(String.t(), Task.t()) :: :ok
  def notify_task_updated(board_id, task) do
    with_board_actor(board_id, fn pid ->
      GenServer.call(pid, {:notify_task_change, task})
    end)
  end

  @doc """
  Notifies the BoardActor that a task was deleted.
  """
  @spec notify_task_deleted(String.t(), String.t()) :: :ok
  def notify_task_deleted(board_id, task_id) do
    with_board_actor(board_id, fn pid ->
      GenServer.call(pid, {:task_deleted, task_id})
    end)
  end

  @doc """
  Requests the BoardActor to refresh its cached column data.
  """
  @spec refresh_columns(String.t()) :: :ok
  def refresh_columns(board_id) do
    with_board_actor(board_id, fn pid ->
      GenServer.cast(pid, :refresh_columns)
    end)
  end

  # ============================================================================
  # Server Callbacks
  # ============================================================================

  @impl true
  def init({callers, board_id}) do
    CallerTracking.restore_callers(callers)
    Logger.info("BoardActor starting for board #{board_id}")

    state = %__MODULE__{
      board_id: board_id,
      task_supervisor_name: task_supervisor_name(board_id),
      task_pids: %{}
    }

    # Load and cache column information
    state = refresh_column_cache(state)

    Logger.info("BoardActor: Cached #{MapSet.size(state.column_ids)} columns for board #{board_id}")

    # Subscribe to PubSub for task changes
    Phoenix.PubSub.subscribe(Viban.PubSub, @task_updates_topic)

    # Initialize existing tasks asynchronously
    send(self(), :init_task_actors)

    {:ok, state}
  end

  @impl true
  def handle_info(:init_task_actors, state) do
    state = spawn_existing_task_actors(state)
    {:noreply, state}
  end

  @impl true
  def handle_info({:task_created, task}, state) when not is_nil(task.column_id) do
    if belongs_to_board?(task.column_id, state) do
      Logger.info("Task created in board #{state.board_id}: #{task.id}")
      state = spawn_task_actor(state, task)
      {:noreply, state}
    else
      Logger.debug(
        "Task #{task.id} column #{task.column_id} not in board #{state.board_id} columns: #{inspect(MapSet.to_list(state.column_ids))}"
      )

      {:noreply, state}
    end
  end

  @impl true
  def handle_info({:task_updated, task}, state) do
    Logger.info("BoardActor: Received task_updated for task #{task.id}, column #{task.column_id}")

    if belongs_to_board?(task.column_id, state) do
      Logger.info("BoardActor: Task #{task.id} belongs to board, ensuring TaskActor exists")
      # Ensure TaskActor exists before notifying
      state = ensure_task_actor_exists(state, task)
      Logger.info("BoardActor: Notifying TaskActor for task #{task.id}")
      notify_task_actor(task)
      {:noreply, state}
    else
      Logger.info(
        "BoardActor: Task #{task.id} does NOT belong to board #{state.board_id}, columns: #{inspect(MapSet.to_list(state.column_ids))}"
      )

      {:noreply, state}
    end
  end

  @impl true
  def handle_info({:task_in_progress_changed, _task_id, _in_progress}, state) do
    # We no longer auto-move tasks based on in_progress changes.
    # The TaskActor command queue handles moves via the executor completion callback.
    {:noreply, state}
  end

  @impl true
  def handle_info({:task_deleted, _task_id}, state) do
    # Task deletion is handled via handle_call
    {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  @impl true
  def handle_call({:notify_task_change, task}, _from, state) do
    if belongs_to_board?(task.column_id, state) do
      notify_task_actor(task)
    end

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:task_created, task}, _from, state) do
    state =
      if belongs_to_board?(task.column_id, state) do
        spawn_task_actor(state, task)
      else
        state
      end

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:task_deleted, task_id}, _from, state) do
    state = terminate_task_actor(state, task_id)
    {:reply, :ok, state}
  end

  @impl true
  def handle_cast(:refresh_columns, state) do
    {:noreply, refresh_column_cache(state)}
  end

  # ============================================================================
  # Column Cache Management
  # ============================================================================

  defp refresh_column_cache(state) do
    case Viban.Kanban.Actors.ColumnLookup.get_board_columns(state.board_id) do
      {:ok, columns} ->
        column_ids = MapSet.new(columns, & &1.id)

        Logger.debug("BoardActor #{state.board_id}: Loaded column IDs: #{inspect(MapSet.to_list(column_ids))}")

        %{state | column_ids: column_ids}

      {:error, reason} ->
        Logger.warning("Failed to load columns for board #{state.board_id}: #{inspect(reason)}")
        state
    end
  end

  defp belongs_to_board?(column_id, %{column_ids: column_ids}) do
    MapSet.member?(column_ids, column_id)
  end

  # ============================================================================
  # Task Actor Management
  # ============================================================================

  defp spawn_existing_task_actors(state) do
    case get_board_tasks(state) do
      {:ok, tasks} ->
        Logger.info("BoardActor #{state.board_id}: Spawning actors for #{length(tasks)} existing tasks")

        Enum.reduce(tasks, state, &spawn_task_actor(&2, &1))

      {:error, reason} ->
        Logger.warning("Failed to load tasks for board #{state.board_id}: #{inspect(reason)}")
        state
    end
  end

  defp get_board_tasks(%{column_ids: column_ids}) do
    column_id_list = MapSet.to_list(column_ids)

    if Enum.empty?(column_id_list) do
      {:ok, []}
    else
      case Task.read() do
        {:ok, tasks} ->
          board_tasks = Enum.filter(tasks, &(&1.column_id in column_id_list))
          {:ok, board_tasks}

        error ->
          error
      end
    end
  end

  defp spawn_task_actor(state, task) do
    callers = CallerTracking.capture_callers()

    case DynamicSupervisor.start_child(
           state.task_supervisor_name,
           {TaskSupervisor, {state.board_id, task, callers}}
         ) do
      {:ok, pid} ->
        Logger.debug("Spawned TaskSupervisor for task #{task.id}")
        %{state | task_pids: Map.put(state.task_pids, task.id, pid)}

      {:error, {:already_started, pid}} ->
        %{state | task_pids: Map.put(state.task_pids, task.id, pid)}

      {:error, reason} ->
        Logger.error("Failed to spawn TaskSupervisor for task #{task.id}: #{inspect(reason)}")
        state
    end
  end

  defp ensure_task_actor_exists(state, task) do
    case Registry.lookup(@registry, {:task_sup, task.id}) do
      [{pid, _}] ->
        Logger.info("TaskSupervisor already exists for task #{task.id}, pid: #{inspect(pid)}")
        state

      [] ->
        Logger.info("Spawning TaskSupervisor for existing task #{task.id} (was missing)")
        spawn_task_actor(state, task)
    end
  end

  defp terminate_task_actor(state, task_id) do
    case Map.get(state.task_pids, task_id) do
      nil ->
        # Try to find and terminate via registry
        terminate_task_actor_by_registry(state, task_id)
        state

      pid ->
        DynamicSupervisor.terminate_child(state.task_supervisor_name, pid)
        %{state | task_pids: Map.delete(state.task_pids, task_id)}
    end
  end

  @spec terminate_task_actor_by_registry(state(), String.t()) :: :ok
  defp terminate_task_actor_by_registry(state, task_id) do
    case Registry.lookup(@registry, {:task_sup, task_id}) do
      [{pid, _}] ->
        DynamicSupervisor.terminate_child(state.task_supervisor_name, pid)

      [] ->
        :ok
    end
  end

  @spec notify_task_actor(Task.t()) :: :ok
  defp notify_task_actor(_task) do
    :ok
  end

  # ============================================================================
  # Helpers
  # ============================================================================

  @spec with_board_actor(String.t(), (pid() -> term())) :: term()
  defp with_board_actor(board_id, fun) do
    case Registry.lookup(@registry, {:board_actor, board_id}) do
      [{pid, _}] -> fun.(pid)
      [] -> :ok
    end
  end

  @spec task_supervisor_name(String.t()) :: {:via, Registry, {atom(), term()}}
  defp task_supervisor_name(board_id) do
    {:via, Registry, {@registry, {:task_supervisor, board_id}}}
  end
end
