defmodule Viban.Kanban.Notifiers.TaskNotifier do
  @moduledoc """
  Ash notifier that broadcasts task changes via PubSub.

  This enables the BoardActor to react to task changes, particularly
  the `in_progress` field changes for automatic column transitions.

  ## Broadcast Topics

  All broadcasts go to the `"task:updates"` topic:

  - `{:task_created, task}` - when a new task is created
  - `{:task_updated, task}` - when a task is updated
  - `{:task_deleted, task_id}` - when a task is deleted
  - `{:task_in_progress_changed, task_id, in_progress}` - when in_progress changes

  ## Usage

  Add this notifier to your Task resource:

      notifiers [Viban.Kanban.Notifiers.TaskNotifier]

  Subscribe to updates in your GenServer:

      Phoenix.PubSub.subscribe(Viban.PubSub, "task:updates")
  """
  use Ash.Notifier

  require Logger

  @pubsub_name Viban.PubSub
  @topic "task:updates"

  @impl true
  def notify(%Ash.Notifier.Notification{
        resource: Viban.Kanban.Task,
        action: %{type: action_type, name: action_name},
        data: task,
        changeset: changeset
      }) do
    Logger.debug("TaskNotifier: #{action_type} (#{action_name}) for task #{task.id}")

    case action_type do
      :create ->
        broadcast_task_created(task)

      :update ->
        handle_update(task, changeset)

      :destroy ->
        broadcast_task_deleted(task.id)
    end

    :ok
  end

  def notify(_notification), do: :ok

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp handle_update(task, changeset) do
    # Check if in_progress changed
    if in_progress_changed?(changeset) do
      Logger.info(
        "TaskNotifier: Broadcasting in_progress_changed for task #{task.id}, " <>
          "in_progress=#{task.in_progress}"
      )

      broadcast_in_progress_changed(task)
    end

    broadcast_task_updated(task)
  end

  defp in_progress_changed?(nil), do: false

  defp in_progress_changed?(changeset) do
    Ash.Changeset.changing_attribute?(changeset, :in_progress)
  end

  defp broadcast_task_created(task) do
    broadcast({:task_created, task})
  end

  defp broadcast_task_updated(task) do
    Logger.info("TaskNotifier: Broadcasting task_updated for task #{task.id}")
    broadcast({:task_updated, task})
  end

  defp broadcast_task_deleted(task_id) do
    broadcast({:task_deleted, task_id})
  end

  defp broadcast_in_progress_changed(task) do
    broadcast({:task_in_progress_changed, task.id, task.in_progress})
  end

  defp broadcast(message) do
    case Phoenix.PubSub.broadcast(@pubsub_name, @topic, message) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.error("TaskNotifier: Failed to broadcast #{inspect(elem(message, 0))}: #{inspect(reason)}")

        :ok
    end
  end
end
