defmodule Viban.Repo.Migrations.AddTaskTemplates do
  @moduledoc """
  Adds task_templates table for board-specific task templates.
  """

  use Ecto.Migration

  def up do
    create table(:task_templates, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :name, :text, null: false
      add :description_template, :text
      add :position, :bigint, null: false, default: 0

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :board_id,
          references(:boards,
            column: :id,
            name: "task_templates_board_id_fkey",
            type: :uuid,
            prefix: "public",
            on_delete: :delete_all
          ),
          null: false
    end

    create index(:task_templates, [:board_id])
  end

  def down do
    drop table(:task_templates)
  end
end
