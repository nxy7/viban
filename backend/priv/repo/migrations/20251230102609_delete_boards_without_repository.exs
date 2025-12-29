defmodule Viban.Repo.Migrations.DeleteBoardsWithoutRepository do
  use Ecto.Migration

  def up do
    # Delete all existing data to start fresh
    # Order matters due to foreign key constraints

    # Delete messages (belong to tasks)
    execute "DELETE FROM messages"

    # Delete column_hooks (belong to columns and hooks)
    execute "DELETE FROM column_hooks"

    # Delete tasks (belong to columns)
    execute "DELETE FROM tasks"

    # Delete columns (belong to boards)
    execute "DELETE FROM columns"

    # Delete hooks (belong to boards)
    execute "DELETE FROM hooks"

    # Delete repositories (belong to boards)
    execute "DELETE FROM repositories"

    # Delete boards
    execute "DELETE FROM boards"
  end

  def down do
    # No way to restore deleted data
    :ok
  end
end
