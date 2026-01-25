defmodule Viban.Kanban.Board.Actions.CreateWithRepository do
  @moduledoc """
  Creates a board with an associated repository.

  This is the single entry point for board creation with a repository.
  """

  use Ash.Resource.Actions.Implementation

  alias Viban.Kanban.Board
  alias Viban.Kanban.Repository

  @impl true
  def run(input, _opts, _context) do
    %{
      name: name,
      description: description,
      user_id: user_id,
      repo: repo
    } = input.arguments

    with {:ok, board} <- Board.create(%{name: name, description: description, user_id: user_id}),
         {:ok, _repository} <- create_repository(board, repo) do
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
      default_branch: repo.default_branch,
      local_path: Map.get(repo, :local_path)
    })
  end

  defp extract_repo_name(full_name) do
    full_name
    |> String.split("/")
    |> List.last()
  end
end
