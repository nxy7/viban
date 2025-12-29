defmodule Viban.Kanban.Actors.ColumnLookup do
  @moduledoc """
  Centralized column lookup utilities for actor modules.

  Provides efficient column name detection and board membership checking
  to avoid repeated database queries across BoardActor and TaskActor.

  ## Usage

      # Check if a column is "In Progress"
      ColumnLookup.in_progress_column?(column_id)

      # Get all column IDs for a board
      {:ok, column_ids} = ColumnLookup.get_board_column_ids(board_id)

      # Find a specific column by name
      {:ok, column_id} = ColumnLookup.find_column_by_name(board_id, "to review")
  """

  alias Viban.Kanban.Column

  @type column_id :: String.t()
  @type board_id :: String.t()

  @doc """
  Checks if the given column is an "In Progress" column by name.

  Returns `true` if the column exists and its name (case-insensitive) is "in progress".
  """
  @spec in_progress_column?(column_id()) :: boolean()
  def in_progress_column?(nil), do: false

  def in_progress_column?(column_id) do
    case get_column(column_id) do
      {:ok, column} ->
        String.downcase(column.name) == "in progress"

      {:error, _} ->
        false
    end
  end

  @doc """
  Checks if the given column is a "To Review" column by name.

  Returns `true` if the column exists and its name (case-insensitive) is "to review".
  """
  @spec to_review_column?(column_id()) :: boolean()
  def to_review_column?(nil), do: false

  def to_review_column?(column_id) do
    case get_column(column_id) do
      {:ok, column} ->
        String.downcase(column.name) == "to review"

      {:error, _} ->
        false
    end
  end

  @doc """
  Checks if a column matches a specific name (case-insensitive).
  """
  @spec column_has_name?(column_id(), String.t()) :: boolean()
  def column_has_name?(nil, _name), do: false

  def column_has_name?(column_id, name) when is_binary(name) do
    case get_column(column_id) do
      {:ok, column} ->
        String.downcase(column.name) == String.downcase(name)

      {:error, _} ->
        false
    end
  end

  @doc """
  Finds a column by name within a specific board.

  Returns `{:ok, column_id}` if found, `{:error, :not_found}` otherwise.
  """
  @spec find_column_by_name(board_id(), String.t()) :: {:ok, column_id()} | {:error, :not_found}
  def find_column_by_name(board_id, name) when is_binary(name) do
    normalized_name = String.downcase(name)

    case get_board_columns(board_id) do
      {:ok, columns} ->
        case Enum.find(columns, &(String.downcase(&1.name) == normalized_name)) do
          %{id: id} -> {:ok, id}
          nil -> {:error, :not_found}
        end

      {:error, _} ->
        {:error, :not_found}
    end
  end

  @doc """
  Gets all column IDs for a specific board.

  Returns `{:ok, [column_id]}` or `{:error, reason}`.
  """
  @spec get_board_column_ids(board_id()) :: {:ok, [column_id()]} | {:error, term()}
  def get_board_column_ids(board_id) do
    case get_board_columns(board_id) do
      {:ok, columns} ->
        {:ok, Enum.map(columns, & &1.id)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Checks if a task (by its column_id) belongs to a specific board.
  """
  @spec task_belongs_to_board?(column_id(), board_id()) :: boolean()
  def task_belongs_to_board?(nil, _board_id), do: false

  def task_belongs_to_board?(column_id, board_id) do
    case get_board_column_ids(board_id) do
      {:ok, column_ids} -> column_id in column_ids
      {:error, _} -> false
    end
  end

  @doc """
  Gets all columns for a board.

  Returns `{:ok, [column]}` or `{:error, reason}`.
  """
  @spec get_board_columns(board_id()) :: {:ok, [Column.t()]} | {:error, term()}
  def get_board_columns(board_id) do
    import Ash.Query

    Column
    |> filter(board_id == ^board_id)
    |> Ash.read()
  end

  @doc """
  Gets a single column by ID.
  """
  @spec get_column(column_id()) :: {:ok, Column.t()} | {:error, term()}
  def get_column(column_id) do
    Column.get(column_id)
  end

  @doc """
  Finds the "To Review" column for a board.

  Returns the column ID if found, nil otherwise.
  """
  @spec find_to_review_column(board_id()) :: column_id() | nil
  def find_to_review_column(board_id) do
    case find_column_by_name(board_id, "to review") do
      {:ok, column_id} -> column_id
      {:error, _} -> nil
    end
  end

  @doc """
  Finds the "In Progress" column for a board.

  Returns the column ID if found, nil otherwise.
  """
  @spec find_in_progress_column(board_id()) :: column_id() | nil
  def find_in_progress_column(board_id) do
    case find_column_by_name(board_id, "in progress") do
      {:ok, column_id} -> column_id
      {:error, _} -> nil
    end
  end
end
