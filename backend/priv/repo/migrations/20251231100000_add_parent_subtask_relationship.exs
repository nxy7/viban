defmodule Viban.Repo.Migrations.AddParentSubtaskRelationship do
  use Ecto.Migration

  def change do
    alter table(:tasks) do
      add :parent_task_id, references(:tasks, on_delete: :delete_all, type: :uuid)
      add :is_parent, :boolean, default: false
      add :subtask_position, :integer, default: 0
      add :subtask_generation_status, :string
    end

    create index(:tasks, [:parent_task_id])
    create index(:tasks, [:parent_task_id, :subtask_position])
  end
end
