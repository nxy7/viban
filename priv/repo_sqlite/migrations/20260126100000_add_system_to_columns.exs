defmodule Viban.RepoSqlite.Migrations.AddSystemToColumns do
  @moduledoc """
  Adds system boolean column and changes position from integer to string for columns table.
  """

  use Ecto.Migration

  def change do
    alter table(:columns) do
      add :system, :boolean, default: false
    end

    # Drop the unique index on position since we're changing its type
    drop_if_exists unique_index(:columns, [:board_id, :position])
  end
end
