defmodule Viban.Kanban.Board.Changes.CreateDefaultColumns do
  @moduledoc """
  Creates default columns when a board is created (SQLite version).
  """

  use Ash.Resource.Change

  alias Viban.Kanban.Column
  alias Viban.Kanban.ColumnHook

  require Logger

  @default_columns [
    %{name: "TODO", position: 0, color: "#6366f1"},
    %{name: "In Progress", position: 1, color: "#f59e0b"},
    %{name: "To Review", position: 2, color: "#8b5cf6"},
    %{name: "Done", position: 3, color: "#10b981"},
    %{name: "Cancelled", position: 4, color: "#ef4444"}
  ]

  @auto_start_hook_id "system:auto-start"
  @execute_ai_hook_id "system:execute-ai"
  @move_task_hook_id "system:move-task"
  @play_sound_hook_id "system:play-sound"

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, &create_default_columns/2)
  end

  defp create_default_columns(_changeset, board) do
    column_inputs =
      Enum.map(@default_columns, fn attrs ->
        Map.put(attrs, :board_id, board.id)
      end)

    case Ash.bulk_create(column_inputs, Column, :create,
           return_errors?: true,
           return_records?: true,
           stop_on_error?: true
         ) do
      %Ash.BulkResult{status: :success, records: columns} ->
        add_default_hooks(columns)
        {:ok, board}

      %Ash.BulkResult{status: :error, errors: errors} ->
        Logger.error("Failed to create default columns: #{inspect(errors)}")
        {:error, "Failed to create default columns"}
    end
  end

  defp add_default_hooks(columns) do
    todo_column = Enum.find(columns, fn col -> col.name == "TODO" end)
    in_progress_column = Enum.find(columns, fn col -> col.name == "In Progress" end)
    to_review_column = Enum.find(columns, fn col -> col.name == "To Review" end)

    if todo_column do
      ColumnHook.create(%{
        column_id: todo_column.id,
        hook_id: @auto_start_hook_id,
        position: 0,
        execute_once: true,
        transparent: false,
        removable: false
      })
    end

    if in_progress_column do
      ColumnHook.create(%{
        column_id: in_progress_column.id,
        hook_id: @execute_ai_hook_id,
        position: 0,
        execute_once: false,
        transparent: false,
        removable: false
      })

      ColumnHook.create(%{
        column_id: in_progress_column.id,
        hook_id: @move_task_hook_id,
        position: 1,
        execute_once: false,
        transparent: true,
        removable: false,
        hook_settings: %{target_column: "To Review"}
      })
    end

    if to_review_column do
      ColumnHook.create(%{
        column_id: to_review_column.id,
        hook_id: @play_sound_hook_id,
        position: 0,
        execute_once: false,
        transparent: false,
        removable: true,
        hook_settings: %{sound: "ding"}
      })
    end
  end

  def default_columns, do: @default_columns
end
