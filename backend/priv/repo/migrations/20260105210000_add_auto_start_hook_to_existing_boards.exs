defmodule Viban.Repo.Migrations.AddAutoStartHookToExistingBoards do
  @moduledoc """
  Adds the non-removable "Auto-Start" hook to all existing "TODO" columns
  that don't already have it, and updates existing ones to be non-removable.
  """
  use Ecto.Migration

  def up do
    # First, update any existing Auto-Start hooks to be non-removable
    execute """
    UPDATE column_hooks
    SET removable = false, updated_at = NOW()
    WHERE hook_id = 'system:auto-start'
    AND removable = true
    """

    # Then, add the Auto-Start hook to TODO columns that don't have it
    execute """
    INSERT INTO column_hooks (id, column_id, hook_id, hook_type, position, execute_once, transparent, removable, hook_settings, inserted_at, updated_at)
    SELECT
      gen_random_uuid(),
      c.id,
      'system:auto-start',
      'on_entry',
      0,
      true,
      false,
      false,
      '{}',
      NOW(),
      NOW()
    FROM columns c
    WHERE LOWER(c.name) = 'todo'
    AND NOT EXISTS (
      SELECT 1 FROM column_hooks ch
      WHERE ch.column_id = c.id
      AND ch.hook_id = 'system:auto-start'
    )
    """
  end

  def down do
    # Make Auto-Start hooks removable again
    execute """
    UPDATE column_hooks
    SET removable = true, updated_at = NOW()
    WHERE hook_id = 'system:auto-start'
    """
  end
end
