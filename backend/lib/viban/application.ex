defmodule Viban.Application do
  @moduledoc """
  The Viban OTP Application.

  This module defines the supervision tree for the application, including:
  - Database connection pool
  - PubSub for real-time updates
  - Oban job queue for background processing
  - Kanban actor system for hook execution
  - Executor supervisors for CLI agent processes
  """

  use Application

  @impl true
  def start(_type, _args) do
    Viban.CLI.run()
    setup_deploy_mode()
    run_migrations()
    configure_phoenix_sync()

    children = core_children() ++ optional_children() ++ endpoint_children()

    opts = [strategy: :one_for_one, name: Viban.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    VibanWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  # ============================================================================
  # Deploy Mode & Migrations
  # ============================================================================

  defp setup_deploy_mode do
    if Viban.DeployMode.enabled?() do
      IO.puts("\n#{IO.ANSI.bright()}📦 Viban Deploy Mode#{IO.ANSI.reset()}\n")
      Viban.DeployMode.ensure_data_dir!()
      Viban.DeployMode.ensure_postgres_running!()
      Viban.DeployMode.ensure_secrets!()
    end
  end

  defp run_migrations do
    if Application.get_env(:viban, :auto_migrate, true) do
      IO.puts("#{IO.ANSI.cyan()}🔄 Running migrations...#{IO.ANSI.reset()}")

      try do
        Viban.Release.migrate()
        IO.puts("#{IO.ANSI.green()}✅ Migrations complete!#{IO.ANSI.reset()}")
      rescue
        e in DBConnection.ConnectionError ->
          IO.puts("#{IO.ANSI.red()}❌ Migration failed: #{Exception.message(e)}#{IO.ANSI.reset()}")
          reraise e, __STACKTRACE__
      end
    end
  end

  # ============================================================================
  # Phoenix Configuration
  # ============================================================================

  defp configure_phoenix_sync do
    Application.put_env(
      :viban,
      VibanWeb.Endpoint,
      Keyword.put(
        Application.get_env(:viban, VibanWeb.Endpoint, []),
        :phoenix_sync,
        Phoenix.Sync.plug_opts()
      )
    )
  end

  defp core_children do
    [
      # Tool detection (runs first to log available tools)
      Viban.Tools.Detector,

      # Telemetry and database
      VibanWeb.Telemetry,
      Viban.Repo,

      # Clustering and communication
      {DNSCluster, query: Application.get_env(:viban, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Viban.PubSub},
      {Finch, name: Viban.Finch},

      # Background job processing
      {Oban, Application.fetch_env!(:viban, Oban)},

      # Periodical task scheduler
      Viban.Kanban.Servers.PeriodicalTaskScheduler,

      # Registries for actor system
      {Registry, keys: :unique, name: Viban.Kanban.ActorRegistry},
      {Registry, keys: :unique, name: Viban.Executors.RunnerRegistry},

      # Dynamic supervisor for board actors
      {DynamicSupervisor,
       name: Viban.Kanban.Actors.BoardDynamicSupervisor, strategy: :one_for_one},

      # StateServer monitor for lifecycle tracking
      Viban.StateServer.Monitor,

      # Demo agent for StateServer testing
      Viban.StateServer.DemoAgent
    ]
  end

  defp optional_children do
    # BoardManager is disabled in test env to avoid conflicts with test sandbox
    if Application.get_env(:viban, :start_board_manager, true) do
      [Viban.Kanban.Actors.BoardManager]
    else
      []
    end
  end

  defp endpoint_children do
    [
      Viban.Executors.RunnerSupervisor,
      VibanWeb.Endpoint
    ]
  end
end
