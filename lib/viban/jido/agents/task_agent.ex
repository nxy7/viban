defmodule Viban.Jido.Agents.TaskAgent do
  @moduledoc """
  Jido Agent managing the lifecycle of a single task, including hook execution.

  Replaces the TaskServer GenServer with a pure functional agent + FSM.
  State transitions via `cmd/2` are testable without GenServers.

  ## Signal Routes

  - `viban.task.column_changed` -> HandleColumnChanged + QueueColumnHooks + ExecuteNextHook
  - `viban.executor.completed` -> HandleExecutorCompleted
  - `viban.task.stop_execution` -> StopExecution
  """

  use Jido.Agent,
    name: "task_agent",
    description: "Manages task lifecycle, hook execution, and executor coordination",
    category: "kanban",
    tags: ["task", "hooks", "executor"],
    schema: [
      board_id: [type: :string, required: true],
      task_id: [type: :string, required: true],
      current_column_id: [type: :string],
      worktree_path: [type: :string],
      worktree_branch: [type: :string],
      custom_branch_name: [type: :string],
      status: [type: :atom, default: :idle],
      current_hook_execution_id: [type: :string],
      awaiting_executor: [type: :boolean, default: false]
    ],
    actions: [
      Viban.Jido.Actions.Task.Initialize,
      Viban.Jido.Actions.Task.QueueColumnHooks,
      Viban.Jido.Actions.Task.ExecuteNextHook,
      Viban.Jido.Actions.Task.HandleColumnChanged,
      Viban.Jido.Actions.Task.HandleExecutorCompleted,
      Viban.Jido.Actions.Task.StopExecution
    ]

  alias Viban.Jido.Actions.Task.HandleColumnChanged
  alias Viban.Jido.Actions.Task.HandleExecutorCompleted
  alias Viban.Jido.Actions.Task.StopExecution

  def signal_routes do
    [
      {"viban.task.column_changed", HandleColumnChanged},
      {"viban.executor.completed", HandleExecutorCompleted},
      {"viban.task.stop_execution", StopExecution}
    ]
  end
end
