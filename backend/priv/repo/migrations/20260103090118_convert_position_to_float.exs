defmodule Viban.Repo.Migrations.ConvertPositionToFloat do
  use Ecto.Migration

  def change do
    alter table(:tasks) do
      modify :position, :float, from: :decimal
    end
  end
end
