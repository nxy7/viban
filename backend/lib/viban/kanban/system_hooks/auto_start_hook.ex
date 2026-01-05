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

  alias Viban.Kanban.{Column, Task}

  require Logger

  @impl true
  def id, do: "system:auto-start"

  @impl true
  def name, do: "Auto-Start Task"

  @impl true
  def description do
    "Automatically moves tasks with auto_start: true to In Progress after Todo hooks complete."
  end

  @impl true
  def default_execute_once, do: true

  @impl true
  def default_transparent, do: false

  @impl true
  def execute(task, column, opts) do
    board_id = Keyword.get(opts, :board_id)

    if task.auto_start && todo_column?(column) do
      Logger.info("[AutoStartHook] Auto-starting task #{task.id} - moving to In Progress")

      case find_in_progress_column(board_id) do
        {:ok, in_progress_column} ->
          case Task.move(task, %{column_id: in_progress_column.id}) do
            {:ok, _updated_task} ->
              Logger.info("[AutoStartHook] Task #{task.id} moved to In Progress")
              :ok

            {:error, reason} ->
              Logger.error(
                "[AutoStartHook] Failed to move task #{task.id}: #{inspect(reason)}"
              )

              {:error, "Failed to auto-start task: #{inspect(reason)}"}
          end

        {:error, :not_found} ->
          Logger.warning("[AutoStartHook] No In Progress column found for board #{board_id}")
          :ok
      end
    else
      :ok
    end
  end

  defp todo_column?(column) do
    String.downcase(column.name) == "todo"
  end

  defp find_in_progress_column(board_id) do
    case Column.by_board(board_id) do
      {:ok, columns} ->
        in_progress =
          Enum.find(columns, fn col ->
            String.downcase(col.name) == "in progress"
          end)

        if in_progress do
          {:ok, in_progress}
        else
          {:error, :not_found}
        end

      {:error, _} ->
        {:error, :not_found}
    end
  end
end
