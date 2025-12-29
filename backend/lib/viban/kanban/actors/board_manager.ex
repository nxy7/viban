defmodule Viban.Kanban.Actors.BoardManager do
  @moduledoc """
  Manages BoardSupervisors for all boards.

  This GenServer is responsible for:
  - Starting a BoardSupervisor for each active board on application startup
  - Responding to board creation/deletion events
  - Maintaining a registry of active board IDs

  ## Supervision Tree

  ```
  BoardDynamicSupervisor
  |-- BoardManager (this module)
  |-- BoardSupervisor (board_1)
  |   |-- DynamicSupervisor (task actors)
  |   |-- BoardActor
  |-- BoardSupervisor (board_2)
  |   |-- ...
  ```

  ## Usage

      # Notify when a new board is created
      BoardManager.notify_board_created(board_id)

      # Notify when a board is deleted
      BoardManager.notify_board_deleted(board_id)

  ## Process Registration

  Registered as a named process via `__MODULE__` for easy access.
  """
  use GenServer
  require Logger

  alias Viban.Kanban.Board
  alias Viban.Kanban.Actors.BoardSupervisor

  # Dynamic supervisor for board supervisors
  @board_dynamic_supervisor Viban.Kanban.Actors.BoardDynamicSupervisor

  # Registry for actor lookups
  @registry Viban.Kanban.ActorRegistry

  @typedoc "Internal state tracking managed board IDs"
  @type state :: %{board_ids: MapSet.t(String.t())}

  @typedoc "Board identifier"
  @type board_id :: String.t()

  # ============================================================================
  # Client API
  # ============================================================================

  @doc """
  Starts the BoardManager process.
  """
  @spec start_link(term()) :: GenServer.on_start()
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Notifies the manager that a new board was created.

  Starts a BoardSupervisor for the board if not already running.
  This is idempotent - calling it multiple times for the same board is safe.
  """
  @spec notify_board_created(board_id()) :: :ok | {:error, term()}
  def notify_board_created(board_id) do
    GenServer.call(__MODULE__, {:board_created, board_id})
  end

  @doc """
  Notifies the manager that a board was deleted.

  Stops the BoardSupervisor for the board and removes it from tracking.
  Safe to call even if the board supervisor is not running.
  """
  @spec notify_board_deleted(board_id()) :: :ok | {:error, term()}
  def notify_board_deleted(board_id) do
    GenServer.call(__MODULE__, {:board_deleted, board_id})
  end

  @doc """
  Returns the list of currently managed board IDs.

  Useful for debugging and monitoring.
  """
  @spec list_boards() :: [board_id()]
  def list_boards do
    GenServer.call(__MODULE__, :list_boards)
  end

  # ============================================================================
  # Server Callbacks
  # ============================================================================

  @impl true
  def init(_opts) do
    Logger.info("BoardManager starting...")

    # Start supervisors for existing boards after a short delay
    # to ensure the dynamic supervisor is ready
    send(self(), :init_board_supervisors)

    {:ok, %{board_ids: MapSet.new()}}
  end

  @impl true
  def handle_info(:init_board_supervisors, state) do
    state = start_existing_board_supervisors(state)
    {:noreply, state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("BoardManager received unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  @impl true
  def handle_call({:board_created, board_id}, _from, state) do
    {result, state} = start_board_supervisor(state, board_id)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:board_deleted, board_id}, _from, state) do
    {result, state} = stop_board_supervisor(state, board_id)
    {:reply, result, state}
  end

  @impl true
  def handle_call(:list_boards, _from, state) do
    {:reply, MapSet.to_list(state.board_ids), state}
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp start_existing_board_supervisors(state) do
    case Board.read() do
      {:ok, boards} ->
        Enum.reduce(boards, state, fn board, acc ->
          {_result, new_state} = start_board_supervisor(acc, board.id)
          new_state
        end)

      {:error, reason} ->
        Logger.warning("Failed to load boards: #{inspect(reason)}")
        state
    end
  end

  @spec start_board_supervisor(state(), board_id()) :: {:ok | {:error, term()}, state()}
  defp start_board_supervisor(state, board_id) do
    if MapSet.member?(state.board_ids, board_id) do
      {:ok, state}
    else
      case DynamicSupervisor.start_child(
             @board_dynamic_supervisor,
             {BoardSupervisor, board_id}
           ) do
        {:ok, _pid} ->
          Logger.info("Started BoardSupervisor for board #{board_id}")
          {:ok, %{state | board_ids: MapSet.put(state.board_ids, board_id)}}

        {:error, {:already_started, _pid}} ->
          # Already started, just add to our tracking
          {:ok, %{state | board_ids: MapSet.put(state.board_ids, board_id)}}

        {:error, reason} ->
          Logger.error(
            "Failed to start BoardSupervisor for board #{board_id}: #{inspect(reason)}"
          )

          {{:error, reason}, state}
      end
    end
  end

  @spec stop_board_supervisor(state(), board_id()) :: {:ok | {:error, term()}, state()}
  defp stop_board_supervisor(state, board_id) do
    case Registry.lookup(@registry, {:board_supervisor, board_id}) do
      [{pid, _}] ->
        case DynamicSupervisor.terminate_child(@board_dynamic_supervisor, pid) do
          :ok ->
            Logger.info("Stopped BoardSupervisor for board #{board_id}")
            {:ok, %{state | board_ids: MapSet.delete(state.board_ids, board_id)}}

          {:error, reason} ->
            Logger.warning(
              "Failed to stop BoardSupervisor for board #{board_id}: #{inspect(reason)}"
            )

            {{:error, reason}, %{state | board_ids: MapSet.delete(state.board_ids, board_id)}}
        end

      [] ->
        # Not found, just remove from tracking
        {:ok, %{state | board_ids: MapSet.delete(state.board_ids, board_id)}}
    end
  end
end
