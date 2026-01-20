defmodule Viban.RepoSqlite do
  @moduledoc """
  SQLite repository for the LiveView-based KanbanLite domain.

  This repo uses SQLite for simplified deployment without external database dependencies.
  It enables single-binary deployment via Burrito without needing Postgres or Electric SQL.
  """

  use Ecto.Repo,
    otp_app: :viban,
    adapter: Ecto.Adapters.SQLite3

  @doc """
  Get the database path for the SQLite database.
  Supports configuration via environment variable or config.
  """
  def database_path do
    Application.get_env(:viban, __MODULE__)[:database] ||
      Path.join(data_dir(), "viban.db")
  end

  defp data_dir do
    System.get_env("VIBAN_DATA_DIR") ||
      Path.join(System.user_home!(), ".viban")
  end
end
