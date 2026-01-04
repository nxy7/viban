defmodule Viban.Kanban.Servers.TaskSupervisor do
  @moduledoc """
  Supervises a TaskServer and its HookExecutionServer for a single task.

  Uses `:one_for_one` strategy - if HookExecutionServer crashes, only it restarts.
  TaskServer is notified via the registry when HookExecutionServer restarts.
  """
  use Supervisor

  alias Viban.Kanban.Servers.{TaskServer, HookExecutionServer}

  @registry Viban.Kanban.ActorRegistry

  def start_link({board_id, task}) do
    Supervisor.start_link(__MODULE__, {board_id, task}, name: via_tuple(task.id))
  end

  def via_tuple(task_id) do
    {:via, Registry, {@registry, {:task_supervisor, task_id}}}
  end

  @doc """
  Get the HookExecutionServer pid for a task.
  """
  def get_hook_executor(task_id) do
    case Registry.lookup(@registry, {:hook_executor, task_id}) do
      [{pid, _}] -> {:ok, pid}
      [] -> {:error, :not_found}
    end
  end

  @impl true
  def init({board_id, task}) do
    children = [
      {TaskServer, {board_id, task}},
      {HookExecutionServer,
       %{
         task_id: task.id,
         board_id: board_id
       }}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
