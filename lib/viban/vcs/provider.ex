defmodule Viban.VCS.Provider do
  @moduledoc """
  Behaviour definition for Version Control System providers.

  This abstraction allows Viban to work with multiple git hosting providers
  like GitHub, GitLab, Gitea, etc.
  """

  @type token :: String.t()
  @type repo_id :: String.t()
  @type pr_id :: String.t() | integer()
  @type error :: {:error, term()}

  @type repo :: %{
          id: String.t(),
          name: String.t(),
          full_name: String.t(),
          description: String.t() | nil,
          private: boolean(),
          html_url: String.t(),
          clone_url: String.t(),
          ssh_url: String.t(),
          default_branch: String.t(),
          owner: %{login: String.t(), avatar_url: String.t()},
          permissions: %{admin: boolean(), push: boolean(), pull: boolean()},
          updated_at: String.t(),
          pushed_at: String.t()
        }

  @type branch :: %{
          name: String.t(),
          protected: boolean()
        }

  @type pull_request :: %{
          id: String.t(),
          number: integer(),
          title: String.t(),
          body: String.t() | nil,
          state: String.t(),
          html_url: String.t(),
          head_branch: String.t(),
          base_branch: String.t(),
          head_sha: String.t(),
          created_at: String.t(),
          updated_at: String.t(),
          merged_at: String.t() | nil,
          user: %{login: String.t(), avatar_url: String.t()}
        }

  @type comment :: %{
          id: String.t(),
          body: String.t(),
          html_url: String.t(),
          created_at: String.t(),
          user: %{login: String.t(), avatar_url: String.t()}
        }

  # Repository operations
  @callback list_repos(token, opts :: keyword()) :: {:ok, [repo]} | error
  @callback get_repo(token, owner :: String.t(), repo_name :: String.t()) :: {:ok, repo} | error
  @callback list_branches(token, owner :: String.t(), repo_name :: String.t(), opts :: keyword()) ::
              {:ok, [branch]} | error
  @callback clone_repo(token, clone_url :: String.t(), local_path :: String.t()) ::
              {:ok, String.t()} | error

  # Pull request operations
  @callback create_pull_request(
              token,
              owner :: String.t(),
              repo_name :: String.t(),
              params :: %{
                title: String.t(),
                body: String.t() | nil,
                head: String.t(),
                base: String.t()
              }
            ) :: {:ok, pull_request} | error

  @callback get_pull_request(token, owner :: String.t(), repo_name :: String.t(), pr_id) ::
              {:ok, pull_request} | error

  @callback list_pull_requests(
              token,
              owner :: String.t(),
              repo_name :: String.t(),
              opts :: keyword()
            ) :: {:ok, [pull_request]} | error

  @callback update_pull_request(
              token,
              owner :: String.t(),
              repo_name :: String.t(),
              pr_id,
              params :: %{
                optional(:title) => String.t(),
                optional(:body) => String.t(),
                optional(:state) => String.t()
              }
            ) :: {:ok, pull_request} | error

  # Comment operations
  @callback create_pr_comment(
              token,
              owner :: String.t(),
              repo_name :: String.t(),
              pr_id,
              body :: String.t()
            ) :: {:ok, comment} | error

  @callback list_pr_comments(token, owner :: String.t(), repo_name :: String.t(), pr_id) ::
              {:ok, [comment]} | error

  # User operations
  @callback get_user(token) :: {:ok, map()} | error
end
