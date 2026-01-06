defmodule Viban.Kanban.SystemHooks.MoveTaskHook do
  @moduledoc """
  System hook that moves a task to a target column.

  ## Settings

  The `hook_settings` on the ColumnHook can specify:
  - `target_column`: Column to move to. Options:
    - `"next"` (default) - Move to the next column by position
    - Column name (e.g., "To Review") - Move to specific column by name
  """

  @behaviour Viban.Kanban.SystemHooks.Behaviour

  alias Viban.Kanban.Actors.ColumnLookup
  alias Viban.Kanban.Task

  require Logger

  @impl true
  def id, do: "system:move-task"

  @impl true
  def name, do: "Move Task"

  @impl true
  def description do
    "Moves the task to a target column. Configure 'target_column' in settings: " <>
      "'next' for next column, or a column name like 'To Review'."
  end

  def default_transparent, do: true

  @impl true
  def execute(task, column, opts) do
    hook_settings = Keyword.get(opts, :hook_settings, %{})
    target = get_target(hook_settings)
    board_id = Keyword.get(opts, :board_id)

    Logger.info("[MoveTaskHook] Moving task #{task.id} to target: #{target}")

    case resolve_target_column(target, column, board_id) do
      {:ok, target_column_id} when target_column_id != task.column_id ->
        case Task.move(task, %{column_id: target_column_id}) do
          {:ok, _} ->
            Logger.info("[MoveTaskHook] Successfully moved task #{task.id} to column #{target_column_id}")

            :ok

          {:error, reason} ->
            Logger.warning("[MoveTaskHook] Failed to move task: #{inspect(reason)}")
            :ok
        end

      {:ok, _same_column} ->
        Logger.debug("[MoveTaskHook] Task #{task.id} already in target column")
        :ok

      {:error, reason} ->
        Logger.warning("[MoveTaskHook] Could not resolve target column: #{inspect(reason)}")
        :ok
    end
  end

  defp get_target(settings) when is_map(settings) do
    settings[:target_column] || settings["target_column"] || "next"
  end

  defp get_target(_), do: "next"

  defp resolve_target_column("next", column, board_id) do
    ColumnLookup.find_next_column(board_id, column.position)
  end

  defp resolve_target_column(column_name, _column, board_id) do
    ColumnLookup.find_column_by_name(board_id, column_name)
  end
end
