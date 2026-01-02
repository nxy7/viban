defmodule Viban.Kanban.Task.Changes.CancelHooksOnMove do
  @moduledoc """
  Ash change that signals TaskServer when a task moves to a different column.

  The TaskServer handles all hook cancellation and cleanup synchronously.
  This change just needs to notify the TaskServer about the move.

  The actual cancellation of pending HookExecution records is handled by
  the TaskServer's move/3 function.
  """

  use Ash.Resource.Change
  require Logger

  alias Viban.Kanban.Servers.TaskServer

  @impl true
  @spec change(Ash.Changeset.t(), keyword(), Ash.Resource.Change.context()) :: Ash.Changeset.t()
  def change(changeset, _opts, _context) do
    if Ash.Changeset.changing_attribute?(changeset, :column_id) do
      notify_task_server(changeset)
    else
      changeset
    end
  end

  defp notify_task_server(changeset) do
    task_id = Ash.Changeset.get_data(changeset, :id)
    old_column_id = Ash.Changeset.get_data(changeset, :column_id)
    new_column_id = Ash.Changeset.get_attribute(changeset, :column_id)
    new_position = Ash.Changeset.get_attribute(changeset, :position) || 0.0

    Logger.info(
      "CancelHooksOnMove: Task #{task_id} moving from column #{old_column_id} to #{new_column_id}"
    )

    spawn(fn ->
      case TaskServer.move(task_id, new_column_id, new_position) do
        :ok ->
          Logger.info("CancelHooksOnMove: TaskServer.move completed for task #{task_id}")

        {:error, :not_found} ->
          Logger.debug("CancelHooksOnMove: No TaskServer found for task #{task_id}")

        {:error, reason} ->
          Logger.error("CancelHooksOnMove: TaskServer.move failed: #{inspect(reason)}")
      end
    end)

    changeset
  end
end
