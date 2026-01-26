defmodule Viban.Kanban.Board.Changes.CreateDefaultColumns do
  @moduledoc """
  Creates default columns and their hooks when a board is created.

  ## Default Board Configuration

  This module defines the declarative configuration for new boards.
  All columns and their hooks are defined in `@board_config` for easy auditing.
  """

  use Ash.Resource.Change

  alias Viban.Kanban.Column
  alias Viban.Kanban.ColumnHook

  require Logger

  # =============================================================================
  # Board Configuration
  #
  # This is the single source of truth for default columns and their hooks.
  # Each column can have zero or more hooks that run when tasks enter the column.
  #
  # Hook options:
  #   - hook_id:       System hook ID (system:xxx) or custom hook UUID
  #   - position:      Execution order (lower = first)
  #   - execute_once:  Only run once per task (default: false)
  #   - transparent:   Continue pipeline even if hook fails (default: false)
  #   - removable:     User can remove this hook (default: true)
  #   - hook_settings: Hook-specific configuration map
  # =============================================================================

  @board_config [
    %{
      name: "TODO",
      position: "A",
      color: "#6366f1",
      system: true,
      hooks: [
        %{
          hook_id: "system:auto-start",
          position: 0,
          execute_once: true,
          removable: false
        }
      ]
    },
    %{
      name: "In Progress",
      position: "E",
      color: "#f59e0b",
      system: true,
      hooks: [
        %{
          hook_id: "system:execute-ai",
          position: 0,
          removable: false
        },
        %{
          hook_id: "system:move-task",
          position: 1,
          transparent: true,
          removable: false,
          hook_settings: %{target_column: "To Review"}
        }
      ]
    },
    %{
      name: "To Review",
      position: "I",
      color: "#8b5cf6",
      system: true,
      hooks: [
        %{
          hook_id: "system:play-sound",
          position: 0,
          transparent: true,
          hook_settings: %{sound: "woof"}
        }
      ]
    },
    %{
      name: "Done",
      position: "M",
      color: "#10b981",
      system: true,
      hooks: []
    },
    %{
      name: "Cancelled",
      position: "Q",
      color: "#ef4444",
      system: true,
      hooks: []
    }
  ]

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, &create_default_columns/2)
  end

  defp create_default_columns(_changeset, board) do
    column_inputs =
      Enum.map(@board_config, fn config ->
        config
        |> Map.take([:name, :position, :color, :system])
        |> Map.put(:board_id, board.id)
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
    columns_by_name = Map.new(columns, fn col -> {col.name, col} end)

    Enum.each(@board_config, fn %{name: column_name, hooks: hooks} ->
      case Map.get(columns_by_name, column_name) do
        nil ->
          :ok

        column ->
          Enum.each(hooks, fn hook_config ->
            create_column_hook(column.id, hook_config)
          end)
      end
    end)
  end

  defp create_column_hook(column_id, hook_config) do
    attrs =
      hook_config
      |> Map.put(:column_id, column_id)
      |> Map.put_new(:execute_once, false)
      |> Map.put_new(:transparent, false)
      |> Map.put_new(:removable, true)
      |> Map.put_new(:hook_settings, %{})

    ColumnHook.create(attrs)
  end

  def default_columns do
    Enum.map(@board_config, &Map.take(&1, [:name, :position, :color]))
  end

  def board_config, do: @board_config
end
