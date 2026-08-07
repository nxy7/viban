defmodule Viban.Jido.Actions.AutoStart do
  use Jido.Action,
    name: "auto_start_task",
    description: "Auto-move a task with auto_start: true from Todo to In Progress",
    schema: [
      task_id: [type: :string, required: true],
      board_id: [type: :string, required: true]
    ]

  alias Viban.Kanban.Actors.ColumnLookup
  alias Viban.Kanban.Task

  def run(params, _context) do
    with {:ok, task} <- Task.get(params.task_id),
         true <- task.auto_start,
         {:ok, column} <- Viban.Kanban.Column.get(task.column_id),
         true <- String.downcase(column.name) == "todo",
         {:ok, in_progress_id} <- ColumnLookup.find_column_by_name(params.board_id, "In Progress"),
         {:ok, updated_task} <- Task.move(task, %{column_id: in_progress_id}) do
      {:ok, %{task_id: updated_task.id, moved_to: in_progress_id}}
    else
      false -> {:ok, %{status: :skipped, reason: :not_eligible}}
      {:error, reason} -> {:error, reason}
    end
  end
end
