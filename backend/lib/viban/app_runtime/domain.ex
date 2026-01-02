defmodule Viban.AppRuntime do
  @moduledoc """
  Ash Domain for application runtime information.

  This domain provides resources for querying runtime configuration and
  system capabilities that don't require persistence:
  - Available CLI tools
  - System status
  - Runtime configuration
  """

  use Ash.Domain,
    extensions: [AshTypescript.Domain, AshTypescript.Rpc]

  resources do
    resource Viban.AppRuntime.SystemTools
  end

  typescript_rpc do
    resource Viban.AppRuntime.SystemTools do
      rpc_action(:list_tools, :list_tools)
      rpc_action(:tool_available, :tool_available)
      rpc_action(:available_tools, :available_tools)
      rpc_action(:list_executors, :list_executors)
      rpc_action(:open_in_editor, :open_in_editor)
      rpc_action(:open_folder, :open_folder)
    end
  end
end
