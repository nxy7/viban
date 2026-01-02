defmodule Viban.AppRuntime.SystemTools do
  @moduledoc """
  Ash Resource for querying available system tools.

  This resource provides a read-only interface to check which CLI tools
  are available on the system. It uses the Simple data layer (no persistence)
  as tools are detected at runtime.

  ## Known Tools

  The following tools are recognized by the system:

  ### Core Tools (Required)
  - `:docker` - Container management for PostgreSQL
  - `:git` - Version control and worktree management

  ### Optional Tools
  - `:gh` - GitHub CLI for PR management
  - `:claude` - Claude Code AI executor
  - `:codex` - OpenAI Codex executor
  - `:aider` - Aider AI coding assistant
  - `:goose` - Goose AI coding assistant

  ## Examples

      # Get all tools with their status
      Viban.AppRuntime.SystemTools.list_tools!()
      #=> [%{name: :docker, display_name: "Docker", available: true, ...}, ...]

      # Check if a specific tool is available
      Viban.AppRuntime.SystemTools.tool_available!(:gh)
      #=> true
  """

  use Ash.Resource,
    domain: Viban.AppRuntime,
    data_layer: Ash.DataLayer.Simple,
    extensions: [AshTypescript.Resource]

  alias Viban.Executors.Registry
  alias Viban.Tools.Detector
  alias VibanWeb.PathOpener

  @known_tools [
    :docker,
    :git,
    :gh,
    :claude,
    :codex,
    :aider,
    :goose
  ]

  typescript do
    type_name("SystemTool")
  end

  resource do
    require_primary_key? false
  end

  attributes do
    attribute :name, :atom do
      allow_nil? false
      public? true
      constraints one_of: @known_tools
      description "Tool identifier"
    end

    attribute :display_name, :string do
      allow_nil? false
      public? true
      description "Human-readable tool name"
    end

    attribute :description, :string do
      public? true
      description "What this tool is used for"
    end

    attribute :available, :boolean do
      allow_nil? false
      public? true
      description "Whether this tool is installed and available"
    end

    attribute :version, :string do
      public? true
      description "Detected version of the tool (if available)"
    end

    attribute :category, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:core, :optional]
      description "Tool category - core (required) or optional"
    end

    attribute :feature, :string do
      public? true
      description "Feature enabled by this tool"
    end
  end

  actions do
    action :list_tools, {:array, :map} do
      description "List all known tools with their availability status"

      run fn _input, _context ->
        tools = build_tools_list()
        {:ok, tools}
      end
    end

    action :tool_available, :boolean do
      description "Check if a specific tool is available"

      argument :tool_name, :atom do
        allow_nil? false
        constraints one_of: @known_tools
        description "The tool to check"
      end

      run fn input, _context ->
        {:ok, Detector.available?(input.arguments.tool_name)}
      end
    end

    action :available_tools, {:array, :atom} do
      description "List only the names of available tools"

      run fn _input, _context ->
        tools =
          build_tools_list()
          |> Enum.filter(& &1.available)
          |> Enum.map(& &1.name)

        {:ok, tools}
      end
    end

    action :list_executors, {:array, :map} do
      description "List all available AI executors with their status"

      run fn _input, _context ->
        {:ok, Registry.list_all()}
      end
    end

    action :open_in_editor, :map do
      description "Open a path in the user's code editor"

      argument :path, :string do
        allow_nil? false
        description "The path to open in the editor"
      end

      run fn input, _context ->
        path = input.arguments.path

        with {:ok, dir_path} <- PathOpener.resolve_to_directory(path),
             :ok <- PathOpener.open_in_editor(dir_path) do
          {:ok, %{success: true}}
        else
          {:error, :not_found, path} ->
            {:error,
             Ash.Error.Invalid.InvalidAttribute.exception(
               field: :path,
               message: "Path does not exist: #{path}"
             )}

          {:error, :access_denied, reason} ->
            {:error,
             Ash.Error.Invalid.InvalidAttribute.exception(
               field: :path,
               message: "Cannot access path: #{reason}"
             )}

          {:error, reason} ->
            {:error, Ash.Error.Unknown.exception(error: reason)}
        end
      end
    end

    action :open_folder, :map do
      description "Open a path in the system's file manager"

      argument :path, :string do
        allow_nil? false
        description "The path to open in the file manager"
      end

      run fn input, _context ->
        path = input.arguments.path

        with {:ok, dir_path} <- PathOpener.resolve_to_directory(path),
             :ok <- PathOpener.open_in_file_manager(dir_path) do
          {:ok, %{success: true}}
        else
          {:error, :not_found, path} ->
            {:error,
             Ash.Error.Invalid.InvalidAttribute.exception(
               field: :path,
               message: "Path does not exist: #{path}"
             )}

          {:error, :access_denied, reason} ->
            {:error,
             Ash.Error.Invalid.InvalidAttribute.exception(
               field: :path,
               message: "Cannot access path: #{reason}"
             )}

          {:error, reason} ->
            {:error, Ash.Error.Unknown.exception(error: reason)}
        end
      end
    end
  end

  code_interface do
    define :list_tools
    define :tool_available, args: [:tool_name]
    define :available_tools
    define :list_executors
    define :open_in_editor, args: [:path]
    define :open_folder, args: [:path]
  end

  defp build_tools_list do
    detector_state = Detector.get_all()
    all_tools = detector_state.core ++ detector_state.optional

    Enum.map(all_tools, fn tool ->
      %{
        name: tool.name,
        display_name: tool.display_name,
        description: tool.description,
        available: tool.available,
        version: tool.version,
        category: get_category(tool.name),
        feature: get_feature(tool.name)
      }
    end)
  end

  defp get_category(name) when name in [:docker, :git], do: :core
  defp get_category(_), do: :optional

  defp get_feature(:docker), do: "Database"
  defp get_feature(:git), do: "Version Control"
  defp get_feature(:gh), do: "Pull Requests"
  defp get_feature(:claude), do: "Claude Code Executor"
  defp get_feature(:codex), do: "Codex Executor"
  defp get_feature(:aider), do: "Aider Executor"
  defp get_feature(:goose), do: "Goose Executor"
  defp get_feature(_), do: nil
end
