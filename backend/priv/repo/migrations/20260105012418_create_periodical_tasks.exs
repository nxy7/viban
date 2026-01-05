defmodule Viban.Repo.Migrations.CreatePeriodicalTasks do
  use Ecto.Migration

  def change do
    create table(:periodical_tasks, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :title, :string, null: false
      add :description, :text
      add :schedule, :string, null: false
      add :executor, :string, default: "claude_code"
      add :execution_count, :integer, default: 0, null: false
      add :last_executed_at, :utc_datetime_usec
      add :next_execution_at, :utc_datetime_usec
      add :enabled, :boolean, default: true, null: false
      add :last_created_task_id, :uuid

      add :board_id, references(:boards, type: :uuid, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:periodical_tasks, [:board_id])
    create index(:periodical_tasks, [:enabled, :next_execution_at])

    alter table(:tasks) do
      add :periodical_task_id, references(:periodical_tasks, type: :uuid, on_delete: :nilify_all)
      add :auto_start, :boolean, default: false, null: false
    end

    create index(:tasks, [:periodical_task_id])
  end
end
