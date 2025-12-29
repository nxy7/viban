defmodule Viban.Kanban.Actors.BoardSupervisor do
  @moduledoc """
  Supervises the BoardActor and TaskActor DynamicSupervisor for a single board.

  ## Supervision Strategy

  Uses `:one_for_all` strategy because:
  - If the TaskActor DynamicSupervisor crashes, BoardActor needs to restart
    to rebuild its task_pids map
  - If BoardActor crashes, TaskActors should restart to re-register
    with the new BoardActor

  ## Children (started in order)

  1. **DynamicSupervisor** - Manages TaskActor processes for each task
  2. **BoardActor** - Monitors task events and manages TaskActor lifecycle

  ## Registry

  Registered via `Viban.Kanban.ActorRegistry` with key `{:board_supervisor, board_id}`.
  """
  use Supervisor

  alias Viban.Kanban.Actors.BoardActor

  # Registry for actor lookups
  @registry Viban.Kanban.ActorRegistry

  # Supervision strategy - all children restart together
  @supervision_strategy :one_for_all

  # TaskActor supervision strategy - each child restarts independently
  @task_supervision_strategy :one_for_one

  @typedoc "Board identifier"
  @type board_id :: String.t()

  # ============================================================================
  # Client API
  # ============================================================================

  @doc """
  Starts the BoardSupervisor for a specific board.

  The supervisor will start a DynamicSupervisor for task actors and a BoardActor
  to manage the task lifecycle.
  """
  @spec start_link(board_id()) :: Supervisor.on_start()
  def start_link(board_id) do
    Supervisor.start_link(__MODULE__, board_id, name: via_tuple(board_id))
  end

  @doc """
  Returns the via tuple for registry lookup.
  """
  @spec via_tuple(board_id()) :: {:via, Registry, {atom(), term()}}
  def via_tuple(board_id) do
    {:via, Registry, {@registry, {:board_supervisor, board_id}}}
  end

  @doc """
  Returns the name of the task supervisor for a board.

  Used to start and stop TaskActor processes under this board's DynamicSupervisor.
  """
  @spec task_supervisor_name(board_id()) :: {:via, Registry, {atom(), term()}}
  def task_supervisor_name(board_id) do
    {:via, Registry, {@registry, {:task_supervisor, board_id}}}
  end

  # ============================================================================
  # Supervisor Callbacks
  # ============================================================================

  @impl true
  def init(board_id) do
    children = [
      # DynamicSupervisor for TaskActors - started first
      {DynamicSupervisor,
       name: task_supervisor_name(board_id), strategy: @task_supervision_strategy},
      # BoardActor that manages task actors - depends on DynamicSupervisor
      {BoardActor, board_id}
    ]

    Supervisor.init(children, strategy: @supervision_strategy)
  end
end
