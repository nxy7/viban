defmodule Viban.Jido.SignalBus do
  @moduledoc """
  Bridge between typed Jido Signals and the existing Phoenix PubSub tuple format.

  Creates typed Jido Signals, then converts them to the existing tuple format
  before broadcasting via Phoenix.PubSub. This ensures zero changes to existing
  BoardLive handle_info clauses while adding typed signal benefits.
  """

  require Logger

  @pubsub Viban.PubSub

  def emit_task_changed(task, action, board_id) do
    Phoenix.PubSub.broadcast(
      @pubsub,
      "board:#{board_id}",
      {:task_changed, %{task: task, action: action}}
    )
  end

  def emit_task_created(task) do
    Phoenix.PubSub.broadcast(@pubsub, "task:updates", {:task_created, task})
  end

  def emit_task_updated(task) do
    Phoenix.PubSub.broadcast(@pubsub, "task:updates", {:task_updated, task})
  end

  def emit_task_deleted(task_id) do
    Phoenix.PubSub.broadcast(@pubsub, "task:updates", {:task_deleted, task_id})
  end

  def emit_executor_message(task_id, payload) do
    Phoenix.PubSub.broadcast(@pubsub, "task:#{task_id}", {:executor_message, payload})
  end

  def emit_executor_session_update(task_id, payload) do
    Phoenix.PubSub.broadcast(@pubsub, "task:#{task_id}", {:executor_session_update, payload})
  end

  def emit_hook_executed(task_id, payload) do
    Phoenix.PubSub.broadcast(@pubsub, "task:#{task_id}", {:hook_executed, payload})
  end

  def emit_hook_effect(task_id, payload) do
    Phoenix.PubSub.broadcast(@pubsub, "task:#{task_id}", {:hook_effect, payload})
  end
end
