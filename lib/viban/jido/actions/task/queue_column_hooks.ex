defmodule Viban.Jido.Actions.Task.QueueColumnHooks do
  use Jido.Action,
    name: "queue_column_hooks",
    description: "Queue hooks for a task entering a column",
    schema: [
      task_id: [type: :string, required: true],
      column_id: [type: :string, required: true],
      board_id: [type: :string, required: true],
      restart_recovery: [type: :boolean, default: false]
    ]

  alias Viban.Kanban.Column
  alias Viban.Kanban.ColumnHook
  alias Viban.Kanban.Hook
  alias Viban.Kanban.HookExecution
  alias Viban.Kanban.SystemHooks.Registry
  alias Viban.Kanban.Task

  require Logger

  def run(params, _context) do
    task_id = params.task_id
    column_id = params.column_id
    restart_recovery = params[:restart_recovery] || false

    task = get_task_or_nil(task_id)
    hooks_enabled = column_hooks_enabled?(column_id)
    task_in_error = task && task.agent_status == :error
    executed_hooks = (task && task.executed_hooks) || []

    already_queued_column_hook_ids =
      if restart_recovery do
        case HookExecution.for_task_and_column(task_id, column_id) do
          {:ok, executions} -> MapSet.new(executions, & &1.column_hook_id)
          _ -> MapSet.new()
        end
      else
        MapSet.new()
      end

    entry_hooks = get_hooks_for_column(column_id)

    entry_hooks =
      Enum.filter(entry_hooks, fn {column_hook, _hook} ->
        not (column_hook.execute_once and column_hook.id in executed_hooks) and
          not MapSet.member?(already_queued_column_hook_ids, column_hook.id)
      end)

    queued_count =
      if hooks_enabled do
        {transparent_hooks, normal_hooks} =
          Enum.split_with(entry_hooks, fn {column_hook, _hook} -> column_hook.transparent end)

        {hooks_to_execute, hooks_to_skip} =
          if task_in_error do
            {transparent_hooks, normal_hooks}
          else
            {entry_hooks, []}
          end

        Enum.each(hooks_to_skip, fn {column_hook, hook} ->
          create_hook_execution(task_id, column_hook, hook, column_id, :skipped, :error)
        end)

        Enum.each(hooks_to_execute, fn {column_hook, hook} ->
          create_hook_execution(task_id, column_hook, hook, column_id, :pending, nil)
        end)

        length(hooks_to_execute)
      else
        Enum.each(entry_hooks, fn {column_hook, hook} ->
          create_hook_execution(task_id, column_hook, hook, column_id, :skipped, :disabled)
        end)

        0
      end

    {:ok, %{queued_count: queued_count, column_id: column_id}}
  end

  defp create_hook_execution(task_id, column_hook, hook, column_id, status, skip_reason) do
    attrs = %{
      task_id: task_id,
      hook_name: hook.name,
      hook_id: column_hook.hook_id,
      hook_settings: column_hook.hook_settings || %{},
      triggering_column_id: column_id,
      column_hook_id: column_hook.id
    }

    case HookExecution.queue(attrs) do
      {:ok, execution} ->
        if status == :skipped do
          HookExecution.skip(execution, %{skip_reason: skip_reason})
        end

        execution

      {:error, reason} ->
        Logger.error("Failed to create hook execution: #{inspect(reason)}")
        nil
    end
  end

  defp get_hooks_for_column(column_id) do
    case ColumnHook.read() do
      {:ok, column_hooks} ->
        column_hooks
        |> Enum.filter(&(&1.column_id == column_id))
        |> Enum.sort_by(& &1.position)
        |> Enum.map(fn ch ->
          case get_hook(ch.hook_id) do
            {:ok, hook} -> {ch, hook}
            _ -> nil
          end
        end)
        |> Enum.reject(&is_nil/1)

      _ ->
        []
    end
  end

  defp get_hook(hook_id) do
    if Registry.system_hook?(hook_id) do
      Registry.get(hook_id)
    else
      Hook.get(hook_id)
    end
  end

  defp column_hooks_enabled?(column_id) do
    case Column.get(column_id) do
      {:ok, column} -> column.settings["hooks_enabled"] != false
      _ -> true
    end
  end

  defp get_task_or_nil(task_id) do
    case Task.get(task_id) do
      {:ok, task} -> task
      _ -> nil
    end
  end
end
