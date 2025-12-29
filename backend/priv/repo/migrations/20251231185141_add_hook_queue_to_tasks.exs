defmodule Viban.Repo.Migrations.AddHookQueueToTasks do
  use Ecto.Migration

  def change do
    alter table(:tasks) do
      add :hook_queue, {:array, :map}, default: []
    end
  end
end
