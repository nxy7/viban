defmodule Viban.StateServer.Monitor do
  @moduledoc """
  Monitors all StateServer processes and sets status to `:stopped` when they die.

  StateServers automatically register with this monitor during init.
  When a monitored process dies, the monitor updates its persisted status to `:stopped`.
  """

  use GenServer

  alias Viban.StateServer.Persistence

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  Registers a StateServer process with the monitor.

  Called automatically by `Viban.StateServer.Core.init_state/3`.
  """
  @spec register(module(), String.t(), pid()) :: :ok
  def register(module, actor_id, pid) do
    GenServer.cast(__MODULE__, {:register, module, actor_id, pid})
  end

  @impl true
  def init(_opts) do
    {:ok, %{refs: %{}}}
  end

  @impl true
  def handle_cast({:register, module, actor_id, pid}, state) do
    ref = Process.monitor(pid)
    new_refs = Map.put(state.refs, ref, {module, actor_id})
    {:noreply, %{state | refs: new_refs}}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
    case Map.pop(state.refs, ref) do
      {{module, actor_id}, new_refs} ->
        Persistence.update_status_async(module, actor_id, :stopped, nil)
        {:noreply, %{state | refs: new_refs}}

      {nil, _refs} ->
        {:noreply, state}
    end
  end
end
