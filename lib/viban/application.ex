defmodule Viban.Application do
  @moduledoc """
  The Viban OTP Application.

  This module defines the supervision tree for the application, including:
  - SQLite database connection
  - PubSub for real-time updates
  - Oban job queue for background processing
  - Kanban actor system for hook execution
  - Executor supervisors for CLI agent processes
  """

  use Application

  @impl true
  def start(_type, _args) do
    Viban.CLI.run()
    setup_sqlite()
    setup_deploy_mode()
    run_migrations()

    children = core_children() ++ optional_children() ++ endpoint_children()

    opts = [strategy: :one_for_one, name: Viban.Supervisor]
    result = Supervisor.start_link(children, opts)

    case result do
      {:ok, _pid} -> Viban.Browser.open()
      _ -> :ok
    end

    result
  end

  @impl true
  def config_change(changed, _new, removed) do
    VibanWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  @impl true
  def stop(_state) do
    :ok
  end

  # ============================================================================
  # Setup Functions
  # ============================================================================

  defp setup_sqlite do
    db_path = Application.get_env(:viban, Viban.RepoSqlite)[:database]

    if db_path do
      db_dir = Path.dirname(db_path)

      if !File.dir?(db_dir) do
        IO.puts("#{IO.ANSI.cyan()}📁 Creating SQLite data directory: #{db_dir}#{IO.ANSI.reset()}")
        File.mkdir_p!(db_dir)
      end
    end
  end

  defp setup_deploy_mode do
    if Viban.DeployMode.enabled?() do
      IO.puts("\n#{IO.ANSI.bright()}📦 Viban Deploy Mode#{IO.ANSI.reset()}\n")
      Viban.DeployMode.ensure_data_dir!()
      Viban.DeployMode.ensure_secrets!()
    end
  end

  defp run_migrations do
    if Application.get_env(:viban, :auto_migrate, true) do
      IO.puts("#{IO.ANSI.cyan()}🔄 Running migrations...#{IO.ANSI.reset()}")
      Viban.Release.migrate()
      IO.puts("#{IO.ANSI.green()}✅ Migrations complete!#{IO.ANSI.reset()}")
    end
  end

  # ============================================================================
  # Supervision Tree
  # ============================================================================

  defp core_children do
    [
      Viban.Tools.Detector,
      VibanWeb.Telemetry,
      Viban.RepoSqlite,
      {DNSCluster, query: Application.get_env(:viban, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Viban.PubSub},
      {Finch, name: Viban.Finch},
      {Oban, AshOban.config([Viban.AppRuntime], Application.fetch_env!(:viban, Oban))},
      Viban.Kanban.PeriodicalTask.PeriodicalTaskScheduler,
      {Registry, keys: :unique, name: Viban.Kanban.ActorRegistry},
      {Registry, keys: :unique, name: Viban.Executors.RunnerRegistry},
      {DynamicSupervisor, name: Viban.Kanban.Actors.BoardDynamicSupervisor, strategy: :one_for_one}
    ]
  end

  defp optional_children do
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
