defmodule Viban.Kanban.Board.Changes.CreateDefaultColumns do
  @moduledoc """
  Ash change that creates default columns when a board is created.

  This creates the standard Kanban workflow columns:
  - TODO (position 0) - Indigo, with non-removable "Auto-Start" hook
  - In Progress (position 1) - Amber, with non-removable "Execute AI" hook
  - To Review (position 2) - Violet
  - Done (position 3) - Emerald
  - Cancelled (position 4) - Red

  ## Implementation

  Uses bulk creation for efficiency - all columns are created in a single
  database transaction rather than individual inserts.
  """

  use Ash.Resource.Change

  alias Viban.Kanban.Board
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

  @impl true
  @spec change(Ash.Changeset.t(), keyword(), Ash.Resource.Change.context()) :: Ash.Changeset.t()
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, &create_default_columns/2)
  end

  @spec create_default_columns(Ash.Changeset.t(), Board.t()) ::
          {:ok, Board.t()} | {:error, term()}
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
        # Add the non-removable "Execute AI" hook to the "In Progress" column
        add_default_hooks(columns)
        {:ok, board}

      %Ash.BulkResult{status: :error, errors: errors} ->
        Logger.error("Failed to create default columns for board #{board.id}: #{inspect(errors)}")
        {:error, "Failed to create default columns"}
    end
  end

  defp add_default_hooks(columns) do
    todo_column = Enum.find(columns, fn col -> col.name == "TODO" end)
    in_progress_column = Enum.find(columns, fn col -> col.name == "In Progress" end)

    if todo_column do
      case ColumnHook.create(%{
             column_id: todo_column.id,
             hook_id: @auto_start_hook_id,
             position: 0,
             execute_once: true,
             transparent: false,
             removable: false
           }) do
        {:ok, _} ->
          Logger.debug("Added 'Auto-Start' hook to 'TODO' column #{todo_column.id}")

        {:error, error} ->
          Logger.warning("Failed to add 'Auto-Start' hook: #{inspect(error)}")
      end
    end

    if in_progress_column do
      case ColumnHook.create(%{
             column_id: in_progress_column.id,
             hook_id: @execute_ai_hook_id,
             position: 0,
             execute_once: false,
             transparent: false,
             removable: false
           }) do
        {:ok, _} ->
          Logger.debug("Added 'Execute AI' hook to 'In Progress' column #{in_progress_column.id}")

        {:error, error} ->
          Logger.warning("Failed to add 'Execute AI' hook: #{inspect(error)}")
      end

      case ColumnHook.create(%{
             column_id: in_progress_column.id,
             hook_id: @move_task_hook_id,
             position: 1,
             execute_once: false,
             transparent: true,
             removable: false,
             hook_settings: %{target_column: "To Review"}
           }) do
        {:ok, _} ->
          Logger.debug("Added 'Move Task' hook to 'In Progress' column #{in_progress_column.id}")

        {:error, error} ->
          Logger.warning("Failed to add 'Move Task' hook: #{inspect(error)}")
      end
    end
  end

  @doc """
  Returns the list of default column definitions.

  Useful for testing or documentation purposes.
  """
  @spec default_columns() :: [map()]
  def default_columns, do: @default_columns
end
