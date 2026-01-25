defmodule Viban.Kanban.HookExecution.HookExecutionNotifier do
  @moduledoc """
  Ash notifier that broadcasts HookExecution state changes to PubSub.

  This is a cross-cutting concern - hooks don't need to know about broadcasting.
  All state transitions (queue, start, complete, fail, cancel, skip) are
  automatically broadcast to `task:{task_id}` topic.
  """

  use Ash.Notifier

  alias Viban.Kanban.TaskActivityNotifier

  @impl true
  def notify(%Ash.Notifier.Notification{resource: Viban.Kanban.HookExecution, data: execution}) do
    TaskActivityNotifier.broadcast_hook_execution(execution.task_id, execution)
    :ok
  end
end
