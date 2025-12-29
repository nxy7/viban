defmodule Viban.Repo.Migrations.AddTransparentToColumnHooks do
  @moduledoc """
  Adds transparent flag to column_hooks.

  Transparent hooks:
  - Execute even when task is in error state
  - Don't change task's agent_status when they complete or fail
  - Useful for notification hooks like "Play Sound"
  """

  use Ecto.Migration

  def change do
    alter table(:column_hooks) do
      add :transparent, :boolean, default: false, null: false
    end
  end
end
