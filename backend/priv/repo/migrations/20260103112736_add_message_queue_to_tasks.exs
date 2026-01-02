defmodule Viban.Repo.Migrations.AddMessageQueueToTasks do
  use Ecto.Migration

  def change do
    alter table(:tasks) do
      add :message_queue, {:array, :map}, default: []
    end
  end
end
