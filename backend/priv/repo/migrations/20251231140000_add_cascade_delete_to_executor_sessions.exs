defmodule Viban.Repo.Migrations.AddCascadeDeleteToExecutorSessions do
  @moduledoc """
  Add cascade delete to executor_sessions and executor_messages foreign keys.
  This ensures that when a task is deleted, its executor sessions and messages are also deleted.
  """

  use Ecto.Migration

  def up do
    # Drop and recreate executor_sessions foreign key with cascade delete
    drop constraint(:executor_sessions, "executor_sessions_task_id_fkey")

    alter table(:executor_sessions) do
      modify :task_id,
             references(:tasks,
               column: :id,
               name: "executor_sessions_task_id_fkey",
               type: :uuid,
               prefix: "public",
               on_delete: :delete_all
             )
    end

    # Drop and recreate executor_messages foreign key with cascade delete
    drop constraint(:executor_messages, "executor_messages_session_id_fkey")

    alter table(:executor_messages) do
      modify :session_id,
             references(:executor_sessions,
               column: :id,
               name: "executor_messages_session_id_fkey",
               type: :uuid,
               prefix: "public",
               on_delete: :delete_all
             )
    end
  end

  def down do
    # Revert executor_sessions foreign key
    drop constraint(:executor_sessions, "executor_sessions_task_id_fkey")

    alter table(:executor_sessions) do
      modify :task_id,
             references(:tasks,
               column: :id,
               name: "executor_sessions_task_id_fkey",
               type: :uuid,
               prefix: "public"
             )
    end

    # Revert executor_messages foreign key
    drop constraint(:executor_messages, "executor_messages_session_id_fkey")

    alter table(:executor_messages) do
      modify :session_id,
             references(:executor_sessions,
               column: :id,
               name: "executor_messages_session_id_fkey",
               type: :uuid,
               prefix: "public"
             )
    end
  end
end
