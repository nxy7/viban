defmodule Viban.KanbanLite.Task.TaskNotifier do
  @moduledoc """
  Notifier that broadcasts task changes via Phoenix PubSub (SQLite version).

  Replaces Electric SQL real-time sync with PubSub broadcasts for LiveView.
  """

  use Ash.Notifier

  require Logger

  @impl true
  def notify(notification) do
    task = notification.data
    action = notification.action.name

    broadcast_task_change(task, action)

    :ok
  end

  defp broadcast_task_change(task, action) do
    column = get_column(task.column_id)
    board_id = column && column.board_id

    if board_id do
      Phoenix.PubSub.broadcast(
        Viban.PubSub,
        "kanban_lite:board:#{board_id}",
        {:task_changed, %{task: task, action: action}}
      )
    end
  end

  defp get_column(nil), do: nil

  defp get_column(column_id) do
    case Viban.KanbanLite.Column.get(column_id) do
      {:ok, column} -> column
      _ -> nil
    end
  end
end
