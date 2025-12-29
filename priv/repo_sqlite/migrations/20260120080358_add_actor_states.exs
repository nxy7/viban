defmodule Viban.RepoSqlite.Migrations.AddActorStates do
  @moduledoc """
  Adds the actor_states table for StateServer state persistence.
  """

  use Ecto.Migration

  def up do
    create table(:actor_states, primary_key: false) do
      add :id, :uuid, null: false, primary_key: true
      add :actor_type, :text, null: false
      add :actor_id, :text, null: false
      add :state, :map, null: false, default: %{}
      add :status, :text, null: false
      add :message, :text
      add :version, :bigint, null: false

      add :inserted_at, :utc_datetime_usec, null: false
      add :updated_at, :utc_datetime_usec, null: false
    end

    create unique_index(:actor_states, [:actor_type, :actor_id],
             name: "actor_states_unique_actor_index"
           )
  end

  def down do
    drop_if_exists unique_index(:actor_states, [:actor_type, :actor_id],
                     name: "actor_states_unique_actor_index"
                   )

    drop table(:actor_states)
  end
end
