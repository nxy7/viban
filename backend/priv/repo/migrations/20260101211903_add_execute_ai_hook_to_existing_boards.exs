defmodule Viban.Repo.Migrations.AddExecuteAiHookToExistingBoards do
  @moduledoc """
  Adds the non-removable "Execute AI" hook to all existing "In Progress" columns
  that don't already have it.
  """
  use Ecto.Migration

  def up do
    # Find all "In Progress" columns that don't have the Execute AI hook
    execute """
    INSERT INTO column_hooks (id, column_id, hook_id, hook_type, position, execute_once, transparent, removable, hook_settings, inserted_at, updated_at)
    SELECT
      gen_random_uuid(),
      c.id,
      'system:execute-ai',
      'on_entry',
      0,
      false,
      false,
      false,
      '{}',
      NOW(),
      NOW()
    FROM columns c
    WHERE LOWER(c.name) = 'in progress'
    AND NOT EXISTS (
      SELECT 1 FROM column_hooks ch
      WHERE ch.column_id = c.id
      AND ch.hook_id = 'system:execute-ai'
    )
    """
  end

  def down do
    # Remove the Execute AI hooks that were added by this migration
    # Only remove those that are non-removable (added by this migration)
    execute """
    DELETE FROM column_hooks
    WHERE hook_id = 'system:execute-ai'
    AND removable = false
    """
  end
end
