defmodule Viban.StateServer.Core do
  @moduledoc """
  A GenServer wrapper that automatically persists state to PostgreSQL.

  ## Usage

      defmodule MyServer do
        use Viban.StateServer.Core, restart: :permanent

        defstruct [:task_id, :counter, :temp_pid]

        def start_link(args) do
          GenServer.start_link(__MODULE__, args, name: via_tuple(args.id))
        end

        @impl true
        def init(args) do
          default_state = %__MODULE__{task_id: args.task_id, counter: 0}
          state = Viban.StateServer.Core.init_state(__MODULE__, default_state, args.task_id)
          {:ok, state}
        end

        @impl true
        def handle_cast(:increment, state) do
          # Use update_state/2 to trigger change detection and async persistence
          {:noreply, update_state(state, counter: state.counter + 1)}
        end
      end

  ## Options

  - `:restart` - GenServer restart strategy (default: `:permanent`)

  ## State Updates

  Use `update_state/2` instead of direct struct updates to enable:
  - Change detection (only saves if state actually changed)
  - Async persistence to PostgreSQL
  - Automatic filtering of non-serializable fields

  ## Status Lifecycle

  Automatic status transitions:
  - `:starting` - Set in `init_state/3` when initializing
  - `:ok` - Set after `init_state/3` completes successfully
  - `:stopped` - Set by Monitor when process dies

  Manual status via `set_status/1` or `set_status/2`:
  - `:stopping` - Graceful shutdown in progress
  - `:error` - Actor encountered an error
  """

  alias Viban.StateServer.{Monitor, Persistence, Serializer}

  defmacro __using__(opts) do
    restart = Keyword.get(opts, :restart, :permanent)

    quote do
      use GenServer, restart: unquote(restart)

      import Viban.StateServer.Core, only: [update_state: 2, set_status: 1, set_status: 2]
    end
  end

  @doc """
  Updates state with change detection and async persistence.

  Returns the new state. Only triggers a DB write if the serializable
  portion of the state has actually changed.

  ## Examples

      # Update single field
      new_state = update_state(state, counter: state.counter + 1)

      # Update multiple fields
      new_state = update_state(state, status: :running, started_at: DateTime.utc_now())
  """
  defmacro update_state(state, changes) do
    quote do
      Viban.StateServer.Core.do_update_state(
        __MODULE__,
        unquote(state),
        unquote(changes),
        Process.get(:__state_server_actor_id__)
      )
    end
  end

  @doc """
  Sets the actor status without a message.
  """
  defmacro set_status(status) do
    quote do
      Viban.StateServer.Core.do_set_status(
        __MODULE__,
        Process.get(:__state_server_actor_id__),
        unquote(status),
        nil
      )
    end
  end

  @doc """
  Sets the actor status with a message.
  """
  defmacro set_status(status, message) do
    quote do
      Viban.StateServer.Core.do_set_status(
        __MODULE__,
        Process.get(:__state_server_actor_id__),
        unquote(status),
        unquote(message)
      )
    end
  end

  @doc """
  Initializes state with restoration from DB and lifecycle management.

  Call this in your `init/1` callback:

      def init(args) do
        default_state = %__MODULE__{task_id: args.task_id}
        state = Viban.StateServer.Core.init_state(__MODULE__, default_state, args.task_id)
        {:ok, state}
      end

  This function:
  1. Sets status to `:starting`
  2. Registers with the Monitor for death detection
  3. Loads any persisted state from DB and merges with defaults
  4. Sets status to `:ok`
  """
  @spec init_state(module(), struct() | map(), String.t()) :: struct() | map()
  def init_state(module, default_state, actor_id) do
    Process.put(:__state_server_actor_id__, actor_id)

    Monitor.register(module, actor_id, self())

    state =
      case Persistence.load(module, actor_id) do
        {:ok, persisted} ->
          Persistence.update_status_async(module, actor_id, :ok, nil)
          merge_persisted_state(default_state, persisted)

        :not_found ->
          Persistence.save_with_status_async(module, actor_id, default_state, :ok)
          default_state
      end

    state
  end

  @doc false
  def do_update_state(module, state, changes, actor_id) when is_list(changes) do
    do_update_state(module, state, Map.new(changes), actor_id)
  end

  def do_update_state(module, %{__struct__: _} = state, changes, actor_id) when is_map(changes) do
    new_state = struct(state, changes)

    if state_changed?(state, new_state) and actor_id do
      Persistence.save_async(module, actor_id, new_state)
    end

    new_state
  end

  def do_update_state(module, state, changes, actor_id) when is_map(state) and is_map(changes) do
    new_state = Map.merge(state, changes)

    if state_changed?(state, new_state) and actor_id do
      Persistence.save_async(module, actor_id, new_state)
    end

    new_state
  end

  @doc false
  def do_set_status(module, actor_id, status, message) do
    if actor_id do
      Persistence.update_status_async(module, actor_id, status, message)
    end

    :ok
  end

  defp state_changed?(old_state, new_state) do
    old_serialized = Serializer.serialize(old_state)
    new_serialized = Serializer.serialize(new_state)
    old_serialized != new_serialized
  end

  defp merge_persisted_state(%{__struct__: _module} = default, persisted)
       when is_struct(persisted) do
    default_map = Map.from_struct(default)
    persisted_map = Map.from_struct(persisted)

    merged =
      Enum.reduce(Map.keys(default_map), default_map, fn field, acc ->
        case Map.fetch(persisted_map, field) do
          {:ok, value} when not is_nil(value) -> Map.put(acc, field, value)
          _ -> acc
        end
      end)

    struct(default.__struct__, merged)
  end

  defp merge_persisted_state(%{__struct__: module} = default, persisted) when is_map(persisted) do
    default_map = Map.from_struct(default)

    merged =
      Enum.reduce(Map.keys(default_map), default_map, fn field, acc ->
        case Map.fetch(persisted, field) do
          {:ok, value} when not is_nil(value) -> Map.put(acc, field, value)
          _ -> acc
        end
      end)

    struct(module, merged)
  end

  defp merge_persisted_state(default, persisted) when is_map(default) and is_map(persisted) do
    Map.merge(default, persisted)
  end
end
