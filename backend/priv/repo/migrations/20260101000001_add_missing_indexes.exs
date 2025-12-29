defmodule Viban.Repo.Migrations.AddMissingIndexes do
  @moduledoc """
  Adds indexes on frequently queried foreign key columns to improve query performance.

  - messages.task_id: Used when loading messages for a task
  - column_hooks.column_id: Used when loading hooks for a column
  """
  use Ecto.Migration

  def up do
    # Index for loading messages by task_id (used in for_task action)
    create_if_not_exists index(:messages, [:task_id])

    # Composite index for messages ordered by sequence within a task
    create_if_not_exists index(:messages, [:task_id, :sequence])

    # Index for loading column_hooks by column_id (used when getting hooks for a column)
    create_if_not_exists index(:column_hooks, [:column_id])

    # Composite index for column_hooks ordered by position
    create_if_not_exists index(:column_hooks, [:column_id, :position])
  end

  def down do
    drop_if_exists index(:messages, [:task_id])
    drop_if_exists index(:messages, [:task_id, :sequence])
    drop_if_exists index(:column_hooks, [:column_id])
    drop_if_exists index(:column_hooks, [:column_id, :position])
  end
end
