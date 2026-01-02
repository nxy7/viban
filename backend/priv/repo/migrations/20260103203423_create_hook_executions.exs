defmodule Viban.Repo.Migrations.CreateHookExecutions do
  use Ecto.Migration

  def change do
    create table(:hook_executions, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false

      add :hook_name, :string, null: false
      add :hook_id, :string, null: false

      add :status, :string, null: false, default: "pending"
      add :skip_reason, :string
      add :error_message, :text

      add :hook_settings, :map, default: %{}

      add :queued_at, :utc_datetime_usec, null: false
      add :started_at, :utc_datetime_usec
      add :completed_at, :utc_datetime_usec

      add :triggering_column_id, :uuid

      add :task_id, references(:tasks, type: :uuid, on_delete: :delete_all), null: false
      add :column_hook_id, references(:column_hooks, type: :uuid, on_delete: :nilify_all)

      timestamps(type: :utc_datetime_usec)
    end

    create index(:hook_executions, [:task_id])
    create index(:hook_executions, [:task_id, :status])
    create index(:hook_executions, [:task_id, :queued_at])
  end
end
