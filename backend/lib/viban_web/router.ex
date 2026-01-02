defmodule VibanWeb.Router do
  use VibanWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {VibanWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :fetch_session
    plug VibanWeb.Plugs.LoadUserFromSession
  end

  pipeline :sync do
    plug :accepts, ["json"]
  end

  scope "/", VibanWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # OAuth routes (browser pipeline for redirects)
  scope "/auth", VibanWeb do
    pipe_through :browser

    get "/:provider", AuthController, :request
    get "/:provider/callback", AuthController, :callback
  end

  scope "/api", VibanWeb do
    pipe_through :api

    # Auth endpoints
    get "/auth/me", AuthController, :me
    post "/auth/logout", AuthController, :logout

    # VCS API endpoints (provider-agnostic)
    get "/vcs/repos", VCSController, :list_repos
    get "/vcs/repos/:owner/:repo/branches", VCSController, :list_branches

    # Pull request endpoints
    get "/vcs/repos/:owner/:repo/pulls", VCSController, :list_pull_requests
    get "/vcs/repos/:owner/:repo/pulls/:pr_id", VCSController, :get_pull_request
    post "/vcs/repos/:owner/:repo/pulls", VCSController, :create_pull_request
    patch "/vcs/repos/:owner/:repo/pulls/:pr_id", VCSController, :update_pull_request

    # PR comments
    get "/vcs/repos/:owner/:repo/pulls/:pr_id/comments", VCSController, :list_pr_comments
    post "/vcs/repos/:owner/:repo/pulls/:pr_id/comments", VCSController, :create_pr_comment

    # Board creation with VCS repo
    post "/boards", BoardController, :create

    # Hooks endpoints - list all hooks (system + custom) for a board
    get "/boards/:board_id/hooks", HookController, :index
    get "/hooks/system", HookController, :system_hooks

    # Task actions
    post "/tasks/refine-preview", TaskController, :refine_preview
    post "/tasks/:task_id/refine", TaskController, :refine
    post "/tasks/:task_id/generate_subtasks", TaskController, :generate_subtasks
    get "/tasks/:task_id/subtasks", TaskController, :get_subtasks
    get "/tasks/:task_id/images/:image_id", TaskController, :get_image

    post "/rpc/run", RpcController, :run
    post "/messages/randomize", MessagesController, :randomize
    post "/editor/open", EditorController, :open
    post "/folder/open", FolderController, :open
  end

  scope "/api/shapes", VibanWeb do
    pipe_through :sync

    get "/test_messages", SyncController, :test_messages

    # Kanban shape endpoints
    get "/boards", KanbanSyncController, :boards
    get "/columns", KanbanSyncController, :columns
    get "/tasks", KanbanSyncController, :tasks
    get "/hooks", KanbanSyncController, :hooks
    get "/column_hooks", KanbanSyncController, :column_hooks
    get "/repositories", KanbanSyncController, :repositories
    get "/messages", KanbanSyncController, :messages
  end

  # MCP Server for AI agents
  scope "/mcp" do
    pipe_through :api

    forward "/", AshAi.Mcp.Router,
      domains: [Viban.Kanban],
      otp_app: :viban
  end

  if Application.compile_env(:viban, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: VibanWeb.Telemetry
    end
  end

end
