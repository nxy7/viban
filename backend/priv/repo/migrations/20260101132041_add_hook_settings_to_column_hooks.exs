defmodule Viban.Repo.Migrations.AddHookSettingsToColumnHooks do
  use Ecto.Migration

  def change do
    alter table(:column_hooks) do
      add :hook_settings, :map, default: %{}
    end
  end
end
