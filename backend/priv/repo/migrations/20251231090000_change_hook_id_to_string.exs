defmodule Viban.Repo.Migrations.ChangeHookIdToString do
  @moduledoc """
  Change hook_id in column_hooks from UUID to string to support system hooks.
  System hooks have IDs like "system:refine-prompt" instead of UUIDs.
  """
  use Ecto.Migration

  def up do
    # First, drop the foreign key constraint
    drop_if_exists constraint(:column_hooks, :column_hooks_hook_id_fkey)

    # Change hook_id from UUID to string
    alter table(:column_hooks) do
      modify :hook_id, :string, from: :uuid
    end

    # Add an index on hook_id for faster lookups
    create_if_not_exists index(:column_hooks, [:hook_id])
  end

  def down do
    # Remove the index
    drop_if_exists index(:column_hooks, [:hook_id])

    # Change hook_id back to UUID
    # Note: This will fail if there are any system hook IDs in the table
    alter table(:column_hooks) do
      modify :hook_id, :uuid, from: :string
    end

    # Re-add foreign key constraint
    alter table(:column_hooks) do
      modify :hook_id, references(:hooks, on_delete: :delete_all, type: :uuid), from: :uuid
    end
  end
end
