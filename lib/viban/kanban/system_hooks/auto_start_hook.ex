defmodule Viban.Kanban.SystemHooks.AutoStartHook do
  @moduledoc """
  System hook that auto-moves tasks with `auto_start: true` to In Progress.

  This hook runs on the Todo column after all other hooks complete. If the task
  has `auto_start: true`, it automatically moves the task to the In Progress column,
  triggering the Execute AI hook.

  Use cases:
  - Periodical tasks that should run immediately after creation
  - Tasks created via CreateTaskModal with auto-start enabled
  """

  @behaviour Viban.Kanban.SystemHooks.Behaviour

  alias Viban.Kanban.SystemHooks.MoveTaskHook

  require Logger

  @impl true
  def id, do: "system:auto-start"

  @impl true
  def name, do: "Auto-Start Task"

  @impl true
  def description do
    "Automatically moves tasks with auto_start: true to In Progress after Todo hooks complete."
  end

  def default_execute_once, do: true

  def default_transparent, do: false

  @impl true
  def execute(task, column, opts) do
    if task.auto_start && todo_column?(column) do
      Logger.info("[AutoStartHook] Auto-starting task #{task.id} - delegating to MoveTaskHook")

      opts_with_target = Keyword.put(opts, :hook_settings, %{target_column: "In Progress"})
      MoveTaskHook.execute(task, column, opts_with_target)
    else
      :ok
    end
  end

  defp todo_column?(column) do
    String.downcase(column.name) == "todo"
  end
end
