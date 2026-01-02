defmodule Viban.Repo.Migrations.RemoveHookQueueAndHistory do
  use Ecto.Migration

  def change do
    alter table(:tasks) do
      remove :hook_queue, {:array, :map}, default: []
      remove :hook_history, {:array, :map}, default: []
    end
  end
end
