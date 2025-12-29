defmodule Viban.Repo.Migrations.RenameGithubToProvider do
  @moduledoc """
  Renames GitHub-specific fields to provider-agnostic names.
  Adds provider column to users and repositories tables.
  """

  use Ecto.Migration

  def up do
    # Update users table - rename github_* fields to provider_*
    alter table(:users) do
      add :provider, :text, null: false, default: "github"
    end

    rename table(:users), :github_id, to: :provider_uid
    rename table(:users), :github_login, to: :provider_login
    rename table(:users), :github_access_token, to: :access_token
    rename table(:users), :github_token_expires_at, to: :token_expires_at

    # Change provider_uid from bigint to text (to support different provider ID formats)
    execute """
    ALTER TABLE users
    ALTER COLUMN provider_uid TYPE text USING provider_uid::text
    """

    # Drop old unique index and create new composite one
    drop_if_exists unique_index(:users, [:github_id], name: "users_unique_github_id_index")
    create unique_index(:users, [:provider, :provider_uid], name: "users_unique_provider_uid_index")

    # Update repositories table - rename github_* fields to provider-agnostic names
    alter table(:repositories) do
      add :provider, :text, null: false, default: "github"
    end

    rename table(:repositories), :github_repo_id, to: :provider_repo_id
    rename table(:repositories), :github_full_name, to: :full_name
    rename table(:repositories), :github_clone_url, to: :clone_url
    rename table(:repositories), :github_html_url, to: :html_url

    # Change provider_repo_id from bigint to text
    execute """
    ALTER TABLE repositories
    ALTER COLUMN provider_repo_id TYPE text USING provider_repo_id::text
    """
  end

  def down do
    # Revert repositories table
    execute """
    ALTER TABLE repositories
    ALTER COLUMN provider_repo_id TYPE bigint USING provider_repo_id::bigint
    """

    rename table(:repositories), :provider_repo_id, to: :github_repo_id
    rename table(:repositories), :full_name, to: :github_full_name
    rename table(:repositories), :clone_url, to: :github_clone_url
    rename table(:repositories), :html_url, to: :github_html_url

    alter table(:repositories) do
      remove :provider
    end

    # Revert users table
    drop_if_exists unique_index(:users, [:provider, :provider_uid], name: "users_unique_provider_uid_index")

    execute """
    ALTER TABLE users
    ALTER COLUMN provider_uid TYPE bigint USING provider_uid::bigint
    """

    rename table(:users), :provider_uid, to: :github_id
    rename table(:users), :provider_login, to: :github_login
    rename table(:users), :access_token, to: :github_access_token
    rename table(:users), :token_expires_at, to: :github_token_expires_at

    alter table(:users) do
      remove :provider
    end

    create unique_index(:users, [:github_id], name: "users_unique_github_id_index")
  end
end
