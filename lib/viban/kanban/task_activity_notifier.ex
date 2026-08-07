defmodule Viban.Kanban.TaskActivityNotifier do
  @moduledoc """
  Unified notifier for all task-related activity.

  All task events broadcast to `task:{task_id}` topic via the Jido SignalBus.
  The SignalBus maintains backward compatibility with existing PubSub tuple format.

  ## Event Types

  - `{:executor_message, payload}` - New executor output message
  - `{:executor_session_update, payload}` - Session status change
  - `{:hook_executed, payload}` - Hook execution status change
  - `{:hook_effect, payload}` - Hook effect (e.g., play_sound)
  """

  alias Viban.Jido.SignalBus

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

    SignalBus.emit_executor_message(task_id, payload)
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

    SignalBus.emit_executor_session_update(task_id, payload)
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

    SignalBus.emit_hook_executed(task_id, payload)
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

    SignalBus.emit_hook_effect(task_id, payload)
  end
end
