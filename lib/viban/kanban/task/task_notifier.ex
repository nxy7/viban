defmodule Viban.Kanban.Task.TaskNotifier do
  @moduledoc """
  Notifier that broadcasts task changes via the Jido SignalBus.

  Broadcasts task changes to LiveView subscribers for real-time updates.
  Uses the SignalBus bridge to maintain backward compatibility with
  existing PubSub tuple format.
  """

  use Ash.Notifier

  alias Viban.Jido.SignalBus

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
      SignalBus.emit_task_changed(task, action, board_id)
      broadcast_to_actors(task, action)
    end
  end

  defp broadcast_to_actors(task, :create), do: SignalBus.emit_task_created(task)
  defp broadcast_to_actors(task, :move), do: SignalBus.emit_task_updated(task)
  defp broadcast_to_actors(task, :update), do: SignalBus.emit_task_updated(task)
  defp broadcast_to_actors(task, :destroy), do: SignalBus.emit_task_deleted(task.id)
  defp broadcast_to_actors(_task, _action), do: :ok

  defp get_column(nil), do: nil

  defp get_column(column_id) do
    case Viban.Kanban.Column.get(column_id) do
      {:ok, column} -> column
      _ -> nil
    end
  end
end
