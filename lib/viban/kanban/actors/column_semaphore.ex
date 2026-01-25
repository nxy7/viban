defmodule Viban.Kanban.Actors.ColumnSemaphore do
  @moduledoc """
  Manages concurrency limits for a column.

  Acts as a semaphore that:
  - Tracks currently running tasks
  - Queues tasks when at capacity
  - Releases slots when tasks complete
  - Automatically starts next queued task

  Only active when column has `max_concurrent_tasks` setting.

  ## Usage

      # Request a slot to start execution
      case ColumnSemaphore.request_start(column_id, task_id) do
        :ok -> # Slot acquired, proceed
        {:queued, position} -> # Queued at position, wait for trigger
      end

      # Notify completion
      ColumnSemaphore.task_completed(column_id, task_id)

      # Check status
      {:ok, status} = ColumnSemaphore.get_status(column_id)

  ## Queue Priority

  Tasks are queued in FIFO order by default. Use `prioritize/2` to move
  a task to the front of the queue.

  ## Lifecycle

  Returns `:ignore` during `init/1` if the column doesn't have a valid
  `max_concurrent_tasks` setting, so no process is started.
  """

  use GenServer

  import Ash.Query

  alias Phoenix.PubSub
  alias Viban.Kanban.Column
  alias Viban.Kanban.Task

  require Logger

  # Registry for actor lookups
  @registry Viban.Kanban.ActorRegistry

  # PubSub name
  @pubsub Viban.PubSub

  # Priority value when a task is moved to front of queue
  @high_priority 1000

  # Minimum valid concurrency limit
  @min_concurrent_limit 1

  @typedoc "Task identifier"
  @type task_id :: String.t()

  @typedoc "Column identifier"
  @type column_id :: String.t()

  @typedoc "Position in the queue (1-indexed)"
  @type queue_position :: pos_integer()

  @typedoc "Semaphore status map"
  @type status :: %{
          limited: boolean(),
          max_concurrent: pos_integer() | nil,
          running_count: non_neg_integer() | nil,
          running_tasks: [task_id()] | nil,
          queue_length: non_neg_integer() | nil,
          queued_tasks: [task_id()] | nil
        }

  @type state :: %__MODULE__{
          column_id: column_id(),
          max_concurrent: pos_integer(),
          running_tasks: MapSet.t(task_id()),
          queue: :queue.queue(task_id())
        }

  defstruct [
    :column_id,
    :max_concurrent,
    :running_tasks,
    :queue
  ]

  # ============================================================================
  # Client API
  # ============================================================================

  @doc """
  Starts the ColumnSemaphore for a specific column.

  Returns `:ignore` if the column doesn't have a valid `max_concurrent_tasks` setting.
  """
  @spec start_link(column_id()) :: GenServer.on_start() | :ignore
  def start_link(column_id) do
    GenServer.start_link(__MODULE__, column_id, name: via_tuple(column_id))
  end

  @doc """
  Returns the via tuple for registry lookup.
  """
  @spec via_tuple(column_id()) :: {:via, Registry, {atom(), term()}}
  def via_tuple(column_id) do
    {:via, Registry, {@registry, {:column_semaphore, column_id}}}
  end

  @doc """
  Request to start execution for a task.

  Returns:
  - `:ok` if slot acquired immediately
  - `{:queued, position}` if queued (position is 1-indexed)
  """
  @spec request_start(column_id(), task_id()) :: :ok | {:queued, queue_position()}
  def request_start(column_id, task_id) do
    with_semaphore(column_id, fn pid ->
      GenServer.call(pid, {:request_start, task_id})
    end)
  end

  @doc """
  Notify that a task has completed (releases slot and starts next queued task).
  """
  @spec task_completed(column_id(), task_id()) :: :ok
  def task_completed(column_id, task_id) do
    with_semaphore_cast(column_id, {:task_completed, task_id})
  end

  @doc """
  Notify that a task has left the column (removes from running or queue).
  """
  @spec task_left_column(column_id(), task_id()) :: :ok
  def task_left_column(column_id, task_id) do
    with_semaphore_cast(column_id, {:task_left_column, task_id})
  end

  @doc """
  Move a task to the front of the queue.
  """
  @spec prioritize(column_id(), task_id()) :: :ok | {:error, :no_semaphore | :not_in_queue}
  def prioritize(column_id, task_id) do
    case GenServer.whereis(via_tuple(column_id)) do
      nil -> {:error, :no_semaphore}
      pid -> GenServer.call(pid, {:prioritize, task_id})
    end
  end

  @doc """
  Update the max concurrent limit.
  """
  @spec update_limit(column_id(), pos_integer()) :: :ok | {:error, :no_semaphore}
  def update_limit(column_id, new_limit) when is_integer(new_limit) and new_limit > 0 do
    case GenServer.whereis(via_tuple(column_id)) do
      nil -> {:error, :no_semaphore}
      pid -> GenServer.call(pid, {:update_limit, new_limit})
    end
  end

  @doc """
  Get current queue status.

  Returns a map with:
  - `limited` - whether concurrency limiting is active
  - `max_concurrent` - the configured limit
  - `running_count` - number of currently running tasks
  - `running_tasks` - list of running task IDs
  - `queue_length` - number of queued tasks
  - `queued_tasks` - list of queued task IDs
  """
  @spec get_status(column_id()) :: {:ok, status()}
  def get_status(column_id) do
    case GenServer.whereis(via_tuple(column_id)) do
      nil ->
        {:ok, %{limited: false}}

      pid ->
        GenServer.call(pid, :get_status)
    end
  end

  # ============================================================================
  # Server Callbacks
  # ============================================================================

  @impl true
  def init(column_id) do
    case Column.get(column_id) do
      {:ok, column} ->
        max = get_max_concurrent(column)

        if valid_limit?(max) do
          state = initialize_state(column_id, max)
          Logger.info("ColumnSemaphore started for column #{column_id} with limit #{max}")
          {:ok, state}
        else
          Logger.debug("ColumnSemaphore not starting for column #{column_id}: no valid max_concurrent_tasks setting")

          :ignore
        end

      {:error, reason} ->
        Logger.warning("ColumnSemaphore not starting for column #{column_id}: failed to load column - #{inspect(reason)}")

        :ignore
    end
  end

  @impl true
  def handle_call({:request_start, task_id}, _from, state) do
    cond do
      MapSet.member?(state.running_tasks, task_id) ->
        # Already running
        {:reply, :ok, state}

      has_capacity?(state) ->
        # Has capacity, add to running
        new_running = MapSet.put(state.running_tasks, task_id)
        {:reply, :ok, %{state | running_tasks: new_running}}

      true ->
        # At capacity, add to queue
        state = enqueue_task(state, task_id)
        position = :queue.len(state.queue)
        Logger.info("Task #{task_id} queued at position #{position}")
        {:reply, {:queued, position}, state}
    end
  end

  @impl true
  def handle_call({:prioritize, task_id}, _from, state) do
    queue_list = :queue.to_list(state.queue)

    if task_id in queue_list do
      new_list = [task_id | List.delete(queue_list, task_id)]
      new_queue = :queue.from_list(new_list)
      update_task_priority(task_id, @high_priority)
      {:reply, :ok, %{state | queue: new_queue}}
    else
      {:reply, {:error, :not_in_queue}, state}
    end
  end

  @impl true
  def handle_call({:update_limit, new_limit}, _from, state) do
    Logger.info("Updating concurrency limit from #{state.max_concurrent} to #{new_limit}")
    new_state = %{state | max_concurrent: new_limit}
    new_state = maybe_start_queued_tasks(new_state)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    status = %{
      limited: true,
      max_concurrent: state.max_concurrent,
      running_count: MapSet.size(state.running_tasks),
      running_tasks: MapSet.to_list(state.running_tasks),
      queue_length: :queue.len(state.queue),
      queued_tasks: :queue.to_list(state.queue)
    }

    {:reply, {:ok, status}, state}
  end

  @impl true
  def handle_cast({:task_completed, task_id}, state) do
    if MapSet.member?(state.running_tasks, task_id) do
      Logger.info("Task #{task_id} completed, releasing slot")
      new_running = MapSet.delete(state.running_tasks, task_id)
      new_state = %{state | running_tasks: new_running}
      new_state = maybe_start_queued_tasks(new_state)
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:task_left_column, task_id}, state) do
    new_running = MapSet.delete(state.running_tasks, task_id)
    new_queue = remove_from_queue(state.queue, task_id)
    new_state = %{state | running_tasks: new_running, queue: new_queue}
    new_state = maybe_start_queued_tasks(new_state)
    {:noreply, new_state}
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp with_semaphore(column_id, fun) do
    case GenServer.whereis(via_tuple(column_id)) do
      nil -> :ok
      pid -> fun.(pid)
    end
  end

  defp with_semaphore_cast(column_id, message) do
    case GenServer.whereis(via_tuple(column_id)) do
      nil -> :ok
      pid -> GenServer.cast(pid, message)
    end
  end

  defp get_max_concurrent(column) do
    get_in(column.settings || %{}, ["max_concurrent_tasks"])
  end

  @spec valid_limit?(term()) :: boolean()
  defp valid_limit?(max), do: is_integer(max) and max >= @min_concurrent_limit

  defp has_capacity?(state) do
    MapSet.size(state.running_tasks) < state.max_concurrent
  end

  defp initialize_state(column_id, max) do
    tasks = list_tasks_in_column(column_id)

    running =
      tasks
      |> Enum.filter(& &1.in_progress)
      |> MapSet.new(& &1.id)

    queued =
      tasks
      |> Enum.filter(&(&1.queued_at != nil and not &1.in_progress))
      |> Enum.sort_by(&{-(&1.queue_priority || 0), &1.queued_at})
      |> Enum.map(& &1.id)
      |> :queue.from_list()

    %__MODULE__{
      column_id: column_id,
      max_concurrent: max,
      running_tasks: running,
      queue: queued
    }
  end

  defp list_tasks_in_column(column_id) do
    Task
    |> filter(column_id == ^column_id)
    |> Ash.read!()
  end

  defp enqueue_task(state, task_id) do
    new_queue = :queue.in(task_id, state.queue)
    mark_task_queued(task_id)
    %{state | queue: new_queue}
  end

  defp remove_from_queue(queue, task_id) do
    queue
    |> :queue.to_list()
    |> List.delete(task_id)
    |> :queue.from_list()
  end

  defp maybe_start_queued_tasks(state) do
    available_slots = state.max_concurrent - MapSet.size(state.running_tasks)

    if available_slots > 0 and not :queue.is_empty(state.queue) do
      {{:value, next_task_id}, new_queue} = :queue.out(state.queue)
      Logger.info("Starting queued task #{next_task_id}")

      trigger_task_execution(next_task_id)

      new_running = MapSet.put(state.running_tasks, next_task_id)
      new_state = %{state | running_tasks: new_running, queue: new_queue}

      # Recursively start more if we still have capacity
      maybe_start_queued_tasks(new_state)
    else
      state
    end
  end

  defp mark_task_queued(task_id) do
    case Task.get(task_id) do
      {:ok, task} -> Task.set_queued(task)
      {:error, _} -> :ok
    end
  end

  @spec trigger_task_execution(task_id()) :: :ok
  defp trigger_task_execution(task_id) do
    case Task.get(task_id) do
      {:ok, task} ->
        Task.clear_queued(task)
        PubSub.broadcast(@pubsub, "task:#{task_id}:execute", :start_execution)

      {:error, _} ->
        :ok
    end

    :ok
  end

  defp update_task_priority(task_id, priority) do
    case Task.get(task_id) do
      {:ok, task} -> Task.set_queue_priority(task, %{queue_priority: priority})
      {:error, _} -> :ok
    end
  end
end
