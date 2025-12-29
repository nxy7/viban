defmodule Viban.Repo.Migrations.AddExecuteOnceToColumnHooks do
  use Ecto.Migration

  def change do
    alter table(:column_hooks) do
      add :execute_once, :boolean, default: false
    end

    # Add executed_hooks array to tasks for tracking which hooks have been executed
    alter table(:tasks) do
      add :executed_hooks, {:array, :string}, default: []
    end
  end
end
