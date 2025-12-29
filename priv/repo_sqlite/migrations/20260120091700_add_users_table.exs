defmodule Viban.RepoSqlite.Migrations.AddUsersTable do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :provider, :string, null: false
      add :provider_uid, :string, null: false
      add :provider_login, :string, null: false
      add :name, :string
      add :email, :string
      add :avatar_url, :string
      add :access_token, :string, null: false
      add :token_expires_at, :utc_datetime

      timestamps()
    end

    create unique_index(:users, [:provider, :provider_uid])
  end
end
