defmodule Viban.Repo do
  @moduledoc """
  Ecto repository for the Viban application.

  This module configures the PostgreSQL connection and specifies
  database requirements including minimum version and extensions.

  ## Configuration

  The repository is configured via the `:viban` OTP application config.
  See `config/dev.exs` and `config/prod.exs` for database settings.

  ## Required PostgreSQL Version

  This application requires PostgreSQL 16.0 or higher for optimal
  performance and feature support.

  ## Required Extensions

  - `uuid-ossp` - For UUID generation functions
  """

  use AshPostgres.Repo,
    otp_app: :viban,
    default_prefix: "public",
    warn_on_missing_ash_functions?: false

  @minimum_pg_version %Version{major: 16, minor: 0, patch: 0}
  @required_extensions ["uuid-ossp"]

  @doc """
  Returns the minimum required PostgreSQL version.

  ## Example

      iex> Viban.Repo.min_pg_version()
      %Version{major: 16, minor: 0, patch: 0}
  """
  @spec min_pg_version() :: Version.t()
  def min_pg_version, do: @minimum_pg_version

  @doc """
  Returns the list of PostgreSQL extensions required by this application.

  These extensions must be installed in the database before running migrations.

  ## Example

      iex> Viban.Repo.installed_extensions()
      ["uuid-ossp"]
  """
  @spec installed_extensions() :: [String.t()]
  def installed_extensions, do: @required_extensions
end
