defmodule Viban.Jido.Actions.Task.HandleColumnChanged do
  use Jido.Action,
    name: "handle_column_changed",
    description: "Handle a task moving to a new column: cancel current hooks, queue new ones",
    schema: [
      task_id: [type: :string, required: true],
      board_id: [type: :string, required: true],
      new_column_id: [type: :string, required: true],
      current_column_id: [type: :string]
    ]

  alias Viban.Kanban.Actors.ColumnSemaphore
  alias Viban.Kanban.HookExecution

  require Logger

  def run(params, _context) do
    task_id = params.task_id
    new_column_id = params.new_column_id
    current_column_id = params[:current_column_id]

    if current_column_id == new_column_id do
      {:ok, %{status: :no_change}}
    else
      cancel_pending_executions(task_id, :column_change)

      if current_column_id do
        ColumnSemaphore.task_left_column(current_column_id, task_id)
      end

      {:ok, %{status: :column_changed, new_column_id: new_column_id, previous_column_id: current_column_id}}
    end
  end

  defp cancel_pending_executions(task_id, skip_reason) do
    case HookExecution.active_for_task(task_id) do
      {:ok, executions} ->
        Enum.each(executions, fn exec ->
          HookExecution.cancel(exec, %{skip_reason: skip_reason})
        end)

      {:error, _reason} ->
        :ok
    end
  end
end
