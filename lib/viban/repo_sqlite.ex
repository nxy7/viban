defmodule Viban.RepoSqlite do
  @moduledoc """
  SQLite repository for the Kanban domain.

  Uses SQLite for simplified deployment without external database dependencies.
  Enables single-binary deployment via Burrito.
  """

  use AshSqlite.Repo, otp_app: :viban

  @impl true
  def installed_extensions do
    ["uuid-ossp"]
  end

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
