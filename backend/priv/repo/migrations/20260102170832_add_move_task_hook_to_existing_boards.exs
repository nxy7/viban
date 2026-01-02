defmodule Viban.Repo.Migrations.AddMoveTaskHookToExistingBoards do
  @moduledoc """
  Adds the non-removable "Move Task" hook to all existing "In Progress" columns
  that don't already have it. This hook moves tasks to "To Review" after execution.
  """
  use Ecto.Migration

  def up do
    execute """
    INSERT INTO column_hooks (id, column_id, hook_id, hook_type, position, execute_once, transparent, removable, hook_settings, inserted_at, updated_at)
    SELECT
      gen_random_uuid(),
      c.id,
      'system:move-task',
      'on_entry',
      1,
      false,
      true,
      false,
      '{"target_column": "To Review"}',
      NOW(),
      NOW()
    FROM columns c
    WHERE LOWER(c.name) = 'in progress'
    AND NOT EXISTS (
      SELECT 1 FROM column_hooks ch
      WHERE ch.column_id = c.id
      AND ch.hook_id = 'system:move-task'
    )
    """
  end

  def down do
    execute """
    DELETE FROM column_hooks
    WHERE hook_id = 'system:move-task'
    AND removable = false
    """
  end
end
