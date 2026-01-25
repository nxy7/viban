defmodule Viban.Kanban.Task.TaskNotifier do
  @moduledoc """
  Notifier that broadcasts task changes via Phoenix PubSub.

  Broadcasts task changes to LiveView subscribers for real-time updates.
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

      broadcast_to_actors(task, action)
    end
  end

  defp broadcast_to_actors(task, :create) do
    Phoenix.PubSub.broadcast(Viban.PubSub, "task:updates", {:task_created, task})
  end

  defp broadcast_to_actors(task, :move) do
    Phoenix.PubSub.broadcast(Viban.PubSub, "task:updates", {:task_updated, task})
  end

  defp broadcast_to_actors(task, :update) do
    Phoenix.PubSub.broadcast(Viban.PubSub, "task:updates", {:task_updated, task})
  end

  defp broadcast_to_actors(task, :destroy) do
    Phoenix.PubSub.broadcast(Viban.PubSub, "task:updates", {:task_deleted, task.id})
  end

  defp broadcast_to_actors(_task, _action), do: :ok

  defp get_column(nil), do: nil

  defp get_column(column_id) do
    case Viban.Kanban.Column.get(column_id) do
      {:ok, column} -> column
      _ -> nil
    end
  end
end
