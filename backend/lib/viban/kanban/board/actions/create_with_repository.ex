defmodule Viban.Kanban.Board.Actions.CreateWithRepository do
  @moduledoc """
  Creates a board with an associated repository and enqueues the clone worker.

  This is the single entry point for board creation with a repository.
  """

  use Ash.Resource.Actions.Implementation

  alias Viban.Kanban.Board
  alias Viban.Kanban.Repository
  alias Viban.Workers.RepoCloneWorker

  @impl true
  def run(input, _opts, _context) do
    %{
      name: name,
      description: description,
      user_id: user_id,
      repo: repo
    } = input.arguments

    with {:ok, board} <- Board.create(%{name: name, description: description, user_id: user_id}),
         {:ok, repository} <- create_repository(board, repo) do
      RepoCloneWorker.enqueue(repository.id, user_id)
      {:ok, board}
    end
  end

  defp create_repository(board, repo) do
    Repository.create(%{
      board_id: board.id,
      provider: :github,
      provider_repo_id: to_string(repo.id),
      full_name: repo.full_name,
      clone_url: repo.clone_url,
      html_url: repo.html_url,
      name: extract_repo_name(repo.full_name),
      default_branch: repo.default_branch
    })
  end

  defp extract_repo_name(full_name) do
    full_name
    |> String.split("/")
    |> List.last()
  end
end
