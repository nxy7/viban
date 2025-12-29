defmodule Viban.Repo.Migrations.AddHookHistoryToTasks do
  @moduledoc """
  Adds hook_history column to tasks for persistent hook execution tracking.

  This stores completed hook executions with timestamps so they can be
  displayed in the activity feed.
  """
  use Ecto.Migration

  def change do
    alter table(:tasks) do
      # Store hook execution history: [{id, name, status, executed_at}]
      add :hook_history, {:array, :map}, default: []
    end
  end
end
