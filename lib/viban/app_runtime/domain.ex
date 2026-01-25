defmodule Viban.AppRuntime do
  @moduledoc """
  Ash Domain for application runtime information.

  This domain provides resources for querying runtime configuration and
  system capabilities that don't require persistence:
  - Available CLI tools
  - System status
  - Runtime configuration
  - Application updates
  """

  use Ash.Domain

  alias Viban.AppRuntime.AppUpdates
  alias Viban.AppRuntime.SystemTools

  resources do
    resource SystemTools
    resource AppUpdates
  end
end
