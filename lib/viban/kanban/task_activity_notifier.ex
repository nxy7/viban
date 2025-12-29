defmodule Viban.Kanban.TaskActivityNotifier do
  @moduledoc """
  Unified notifier for all task-related activity.

  All task events broadcast to `task:{task_id}` topic.
  This provides a single channel for the UI to subscribe to for real-time updates.

  ## Event Types

  - `{:executor_message, payload}` - New executor output message
  - `{:executor_session_update, payload}` - Session status change
  - `{:hook_executed, payload}` - Hook execution status change
  """

  require Logger

  @doc """
  Broadcasts a new executor message to the task topic.
  """
  def broadcast_executor_message(task_id, message) do
    payload = %{
      id: message.id,
      task_id: task_id,
      role: message.role,
      content: message.content,
      session_id: message.session_id,
      metadata: message.metadata || %{},
      inserted_at: message.inserted_at
    }

    broadcast(task_id, {:executor_message, payload})
  end

  @doc """
  Broadcasts an executor session status update.
  """
  def broadcast_session_update(task_id, session) do
    payload = %{
      id: session.id,
      task_id: task_id,
      status: session.status,
      exit_code: Map.get(session, :exit_code),
      error_message: Map.get(session, :error_message),
      completed_at: Map.get(session, :completed_at)
    }

    broadcast(task_id, {:executor_session_update, payload})
  end

  @doc """
  Broadcasts a hook execution status change.
  Called automatically by the HookExecution Ash notifier.
  """
  def broadcast_hook_execution(task_id, execution, opts \\ []) do
    status = Keyword.get(opts, :status, execution.status)

    payload = %{
      execution_id: execution.id,
      hook_id: execution.hook_id,
      hook_name: execution.hook_name,
      task_id: task_id,
      triggering_column_id: execution.triggering_column_id,
      status: status,
      error_message: execution.error_message,
      skip_reason: execution.skip_reason,
      started_at: execution.started_at,
      completed_at: execution.completed_at,
      effects: %{}
    }

    broadcast(task_id, {:hook_executed, payload})
  end

  @doc """
  Broadcasts a hook effect (e.g., play_sound).
  Effects are separate from status changes and are triggered by specific hooks.
  """
  def broadcast_hook_effect(task_id, execution, effects) do
    payload = %{
      execution_id: execution.id,
      hook_id: execution.hook_id,
      hook_name: execution.hook_name,
      task_id: task_id,
      effects: effects
    }

    broadcast(task_id, {:hook_effect, payload})
  end

  defp broadcast(task_id, message) do
    topic = "task:#{task_id}"

    Logger.debug("[TaskActivityNotifier] Broadcasting to #{topic}: #{inspect(elem(message, 0))}")

    Phoenix.PubSub.broadcast(Viban.PubSub, topic, message)
  end
end
