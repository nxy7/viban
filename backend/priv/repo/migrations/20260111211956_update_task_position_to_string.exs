defmodule Viban.Repo.Migrations.UpdateTaskPositionToString do
  @moduledoc """
  Converts task position from float to string (fractional indexing).

  This migration:
  1. Adds a temporary position_key column
  2. Converts existing float positions to fractional index strings
  3. Drops the old float position column
  4. Renames position_key to position
  """

  use Ecto.Migration

  def up do
    # Add a temporary column for the new string position
    alter table(:tasks) do
      add :position_key, :text
    end

    # Convert existing float positions to fractional index strings
    # Sort tasks by column and position, then assign sequential keys
    execute """
    WITH ordered_tasks AS (
      SELECT
        id,
        column_id,
        position,
        ROW_NUMBER() OVER (PARTITION BY column_id ORDER BY position ASC, id ASC) as row_num
      FROM tasks
    )
    UPDATE tasks
    SET position_key = (
      SELECT
        CASE
          -- Generate keys like 'a0', 'a1', 'a2', etc. for sequential ordering
          -- This gives plenty of room for insertions between existing items
          WHEN row_num = 1 THEN 'a0'
          ELSE 'a' || (row_num - 1)::text
        END
      FROM ordered_tasks
      WHERE ordered_tasks.id = tasks.id
    )
    """

    # Make position_key not null after populating
    alter table(:tasks) do
      modify :position_key, :text, null: false, default: "a0"
    end

    # Drop the old float column
    alter table(:tasks) do
      remove :position
    end

    # Rename position_key to position
    rename table(:tasks), :position_key, to: :position
  end

  def down do
    # Add a temporary column for the float position
    alter table(:tasks) do
      add :position_float, :float
    end

    # Convert string positions back to floats
    # Simple approach: assign sequential float positions based on current order
    execute """
    WITH ordered_tasks AS (
      SELECT
        id,
        column_id,
        position,
        ROW_NUMBER() OVER (PARTITION BY column_id ORDER BY position ASC, id ASC) as row_num
      FROM tasks
    )
    UPDATE tasks
    SET position_float = (
      SELECT (row_num - 1) * 1000.0
      FROM ordered_tasks
      WHERE ordered_tasks.id = tasks.id
    )
    """

    alter table(:tasks) do
      modify :position_float, :float, null: false, default: 0.0
    end

    alter table(:tasks) do
      remove :position
    end

    rename table(:tasks), :position_float, to: :position
  end
end
