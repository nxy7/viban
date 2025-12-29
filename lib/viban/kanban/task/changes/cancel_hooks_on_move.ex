defmodule Viban.Kanban.Task.Changes.CancelHooksOnMove do
  @moduledoc """
  Ash change that signals TaskServer when a task moves to a different column.

  Uses `after_action` to ensure the database transaction has committed before
  notifying the TaskServer. This guarantees the task is in the new column
  before hooks start executing.
  """

  use Ash.Resource.Change

  require Logger

  @registry Viban.Kanban.ActorRegistry

  @impl true
  def change(changeset, _opts, _context) do
    old_column_id = Ash.Changeset.get_data(changeset, :column_id)
    new_column_id = Ash.Changeset.get_attribute(changeset, :column_id)

    column_actually_changed =
      Ash.Changeset.changing_attribute?(changeset, :column_id) &&
        old_column_id != new_column_id

    if column_actually_changed do
      Logger.info(
        "CancelHooksOnMove: Task #{Ash.Changeset.get_data(changeset, :id)} " <>
          "moving from column #{old_column_id} to #{new_column_id}"
      )

      Ash.Changeset.after_action(changeset, fn _changeset, task ->
        notify_task_server(task)
        {:ok, task}
      end)
    else
      changeset
    end
  end

  defp notify_task_server(task) do
    case Registry.lookup(@registry, {:task_server, task.id}) do
      [{pid, _}] ->
        GenServer.cast(pid, {:column_changed, task.column_id, task.position})
        Logger.info("CancelHooksOnMove: Notified TaskServer for task #{task.id}")

      [] ->
        Logger.debug("CancelHooksOnMove: No TaskServer found for task #{task.id}")
    end
  end
end
