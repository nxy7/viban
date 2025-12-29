defmodule Viban.Repo.Migrations.AddColumnSettings do
  use Ecto.Migration

  def change do
    alter table(:columns) do
      add :settings, :map, default: %{}, null: false
    end
  end
end
