defmodule Viban.Repo.Migrations.CreateTestMessages do
  use Ecto.Migration

  def change do
    create table(:test_messages, primary_key: false) do
      add :id, :uuid, null: false, primary_key: true
      add :text, :string, null: false

      timestamps(type: :utc_datetime_usec)
    end
  end
end
