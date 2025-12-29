defmodule Viban.Repo.Migrations.AddErrorMessageToTasks do
  use Ecto.Migration

  def change do
    alter table(:tasks) do
      add :error_message, :text
    end
  end
end
