defmodule Viban.Repo.Migrations.UpdateRepositoriesForGithub do
  use Ecto.Migration

  def change do
    # Add user_id to boards
    alter table(:boards) do
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
    end

    create index(:boards, [:user_id])

    # Drop old columns from repositories
    alter table(:repositories) do
      remove :path, :string
    end

    # Add new GitHub-related columns
    alter table(:repositories) do
      add :github_repo_id, :bigint, null: false
      add :github_full_name, :string, null: false
      add :github_clone_url, :string, null: false
      add :github_html_url, :string
      add :local_path, :string
      add :clone_status, :string, default: "pending"
      add :clone_error, :string
    end

    create index(:repositories, [:github_repo_id])
  end
end
