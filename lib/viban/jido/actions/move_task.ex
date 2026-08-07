defmodule Viban.Jido.Actions.MoveTask do
  use Jido.Action,
    name: "move_task",
    description: "Move a task to a target column by name or to the next column",
    schema: [
      task_id: [type: :string, required: true],
      board_id: [type: :string, required: true],
      target_column: [type: :string, required: true, doc: "Column name or 'next' for the next column by position"]
    ]

  alias Viban.Kanban.Actors.ColumnLookup
  alias Viban.Kanban.Task

  def run(params, _context) do
    with {:ok, task} <- Task.get(params.task_id),
         {:ok, column} <- Viban.Kanban.Column.get(task.column_id),
         {:ok, target_column_id} <- resolve_target(params.target_column, column, params.board_id),
         {:ok, updated_task} <- Task.move(task, %{column_id: target_column_id}) do
      {:ok, %{task_id: updated_task.id, column_id: target_column_id}}
    end
  end

  defp resolve_target("next", column, board_id) do
    ColumnLookup.find_next_column(board_id, column.position)
  end

  defp resolve_target(column_name, _column, board_id) do
    ColumnLookup.find_column_by_name(board_id, column_name)
  end
end
