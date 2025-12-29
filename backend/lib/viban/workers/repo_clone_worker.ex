defmodule Viban.Workers.RepoCloneWorker do
  @moduledoc """
  Oban worker for cloning VCS repositories in the background.
  Supports multiple providers (GitHub, GitLab, etc.).
  """

  use Oban.Worker,
    queue: :default,
    max_attempts: 3

  alias Viban.Kanban.Repository
  alias Viban.Accounts.User
  alias Viban.VCS

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"repository_id" => repository_id, "user_id" => user_id}}) do
    Logger.info("RepoCloneWorker starting for repository #{repository_id}")

    with {:ok, repo} <- Repository.get(repository_id),
         {:ok, user} <- User.get(user_id) do
      # Mark as cloning
      Repository.set_cloning(repo)

      # Determine local path
      repos_base = get_repos_base_path()
      local_path = Path.join([repos_base, to_string(repo.board_id), repo.name])

      # Create parent directory
      File.mkdir_p!(Path.dirname(local_path))

      # Clone the repository using the appropriate VCS provider
      case VCS.clone_repo(repo.provider, user.access_token, repo.clone_url, local_path) do
        {:ok, _path} ->
          Logger.info("Successfully cloned repository to #{local_path}")
          Repository.set_cloned(repo, %{local_path: local_path})
          :ok

        {:error, {:git_error, code, output}} ->
          error_msg = "Git clone failed (code #{code}): #{String.slice(output, 0, 500)}"
          Logger.error("Failed to clone repository: #{error_msg}")
          Repository.set_clone_error(repo, %{clone_error: error_msg})
          {:error, error_msg}

        {:error, reason} ->
          error_msg = "Clone failed: #{inspect(reason)}"
          Logger.error("Failed to clone repository: #{error_msg}")
          Repository.set_clone_error(repo, %{clone_error: error_msg})
          {:error, error_msg}
      end
    else
      {:error, reason} ->
        Logger.error("RepoCloneWorker failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Enqueue a repository for cloning.
  """
  def enqueue(repository_id, user_id) do
    %{repository_id: repository_id, user_id: user_id}
    |> __MODULE__.new()
    |> Oban.insert()
  end

  defp get_repos_base_path do
    Application.get_env(:viban, :repos_base_path, Path.expand("~/.local/share/viban/repos"))
  end
end
