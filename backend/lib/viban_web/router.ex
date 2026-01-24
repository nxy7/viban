defmodule VibanWeb.Router do
  use VibanWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :put_root_layout, html: {VibanWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :fetch_session
    plug VibanWeb.Plugs.LoadUserFromSession
  end

  # Test endpoints (only available when sandbox_enabled)
  scope "/api/test", VibanWeb do
    pipe_through :api

    get "/status", TestController, :status
    post "/login", TestController, :login
    post "/logout", TestController, :logout
    post "/boards", TestController, :create_board
    delete "/cleanup", TestController, :cleanup
  end

  scope "/api", VibanWeb do
    pipe_through :api

    # Health check (no auth required)
    get "/health", HealthController, :check
    get "/health2", HealthController, :ping
    get "/ping", HealthController, :ping

    # Auth endpoints
    get "/auth/me", AuthController, :me
    post "/auth/logout", AuthController, :logout

    # Device flow auth (no OAuth credentials required)
    post "/auth/device/code", DeviceAuthController, :request_code
    post "/auth/device/poll", DeviceAuthController, :poll
    post "/auth/device/cancel", DeviceAuthController, :cancel
    get "/auth/device/callback", DeviceAuthController, :callback

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
    get "/tasks/:task_id/images/:image_id", TaskController, :get_image

    post "/editor/open", EditorController, :open
    post "/folder/open", FolderController, :open
  end

  # MCP Server for AI agents
  scope "/mcp" do
    pipe_through :api

    forward "/", AshAi.Mcp.Router,
      domains: [Viban.Kanban],
      otp_app: :viban
  end

  if Application.compile_env(:viban, :dev_routes) do
    import Oban.Web.Router

    scope "/dev" do
      pipe_through :browser

      oban_dashboard("/oban")
    end
  end

end
