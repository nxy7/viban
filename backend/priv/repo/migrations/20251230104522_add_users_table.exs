defmodule Viban.Repo.Migrations.AddUsersTable do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :github_id, :bigint, null: false
      add :github_login, :string, null: false
      add :name, :string
      add :email, :string
      add :avatar_url, :string
      add :github_access_token, :string, null: false
      add :github_token_expires_at, :utc_datetime

      timestamps()
    end

    create unique_index(:users, [:github_id])
  end
end
