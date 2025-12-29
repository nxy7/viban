defmodule Viban.Repo.Migrations.SimplifyHooks do
  @moduledoc """
  Removes unused hook fields:
  - cleanup_command: No longer needed as we don't support cleanup commands
  - working_directory: Hooks now always run in the task's worktree
  - timeout_ms: Hooks run until completion without timeout
  """
  use Ecto.Migration

  def change do
    alter table(:hooks) do
      remove :cleanup_command, :text
      remove :working_directory, :text, default: "worktree"
      remove :timeout_ms, :bigint, default: 300000
    end
  end
end
