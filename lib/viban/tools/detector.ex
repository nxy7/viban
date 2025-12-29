defmodule Viban.Tools.Detector do
  @moduledoc """
  Detects available CLI tools on the system at startup.

  This module checks for the presence of various tools that Viban can use
  to provide additional functionality. The results are cached in an Agent
  for quick access throughout the application lifecycle.

  ## Core Tools (Required)
  - git - Version control and worktree management

  ## Optional Tools
  - gh - GitHub CLI for PR functionality
  - claude - Claude Code AI executor
  - codex - OpenAI Codex executor
  - aider - Aider AI coding assistant
  - goose - Goose AI coding assistant
  """

  use Agent

  require Logger

  @core_tools [
    {:git, "Git", "Version control and worktree management"}
  ]

  @optional_tools [
    {:gh, "GitHub CLI", "Pull request creation and management"},
    {:claude, "Claude Code", "AI-powered task execution"},
    {:codex, "OpenAI Codex", "AI-powered task execution"},
    {:aider, "Aider", "AI-powered coding assistant"},
    {:goose, "Goose", "AI-powered coding assistant"}
  ]

  @type tool_status :: %{
          name: atom(),
          display_name: String.t(),
          description: String.t(),
          available: boolean(),
          version: String.t() | nil,
          path: String.t() | nil
        }

  @type tools_state :: %{
          core: [tool_status()],
          optional: [tool_status()],
          detected_at: DateTime.t()
        }

  def start_link(_opts) do
    Agent.start_link(fn -> detect_all_tools() end, name: __MODULE__)
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent
    }
  end

  @doc """
  Returns all detected tools grouped by category.
  """
  @spec get_all() :: tools_state()
  def get_all do
    Agent.get(__MODULE__, & &1)
  end

  @doc """
  Returns only the core tools status.
  """
  @spec get_core_tools() :: [tool_status()]
  def get_core_tools do
    Agent.get(__MODULE__, & &1.core)
  end

  @doc """
  Returns only the optional tools status.
  """
  @spec get_optional_tools() :: [tool_status()]
  def get_optional_tools do
    Agent.get(__MODULE__, & &1.optional)
  end

  @doc """
  Checks if a specific tool is available.
  """
  @spec available?(atom()) :: boolean()
  def available?(tool_name) do
    state = get_all()

    Enum.any?(state.core ++ state.optional, fn tool ->
      tool.name == tool_name and tool.available
    end)
  end

  @doc """
  Re-detects all tools and updates the cached state.
  """
  @spec refresh() :: tools_state()
  def refresh do
    Agent.update(__MODULE__, fn _state -> detect_all_tools() end)
    get_all()
  end

  @doc """
  Returns a list of available AI executor tool names.
  """
  @spec available_executors() :: [atom()]
  def available_executors do
    executor_tools = [:claude, :codex, :aider, :goose]

    get_optional_tools()
    |> Enum.filter(fn tool -> tool.name in executor_tools and tool.available end)
    |> Enum.map(& &1.name)
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp detect_all_tools do
    core = Enum.map(@core_tools, &detect_tool/1)
    optional = Enum.map(@optional_tools, &detect_tool/1)

    state = %{
      core: core,
      optional: optional,
      detected_at: DateTime.utc_now()
    }

    log_detection_results(state)
    state
  end

  defp detect_tool({name, display_name, description}) do
    case System.find_executable(Atom.to_string(name)) do
      nil ->
        %{
          name: name,
          display_name: display_name,
          description: description,
          available: false,
          version: nil,
          path: nil
        }

      path ->
        version = get_tool_version(name, path)

        %{
          name: name,
          display_name: display_name,
          description: description,
          available: true,
          version: version,
          path: path
        }
    end
  end

  defp get_tool_version(tool_name, path) do
    version_args = version_args_for(tool_name)

    case System.cmd(path, version_args, stderr_to_stdout: true) do
      {output, 0} -> parse_version(output)
      _ -> nil
    end
  rescue
    _ -> nil
  end

  defp version_args_for(:git), do: ["--version"]
  defp version_args_for(:gh), do: ["--version"]
  defp version_args_for(:claude), do: ["--version"]
  defp version_args_for(:codex), do: ["--version"]
  defp version_args_for(:aider), do: ["--version"]
  defp version_args_for(:goose), do: ["--version"]
  defp version_args_for(_), do: ["--version"]

  defp parse_version(output) do
    output
    |> String.trim()
    |> String.split("\n")
    |> List.first()
    |> case do
      nil -> nil
      line -> extract_version_number(line)
    end
  end

  defp extract_version_number(line) do
    case Regex.run(~r/(\d+\.\d+(?:\.\d+)?(?:-[\w.]+)?)/, line) do
      [_, version] -> version
      _ -> String.slice(line, 0, 50)
    end
  end

  defp log_detection_results(state) do
    Logger.info("[Tools.Detector] Tool detection complete:")

    Logger.info("[Tools.Detector] Core tools:")

    Enum.each(state.core, fn tool ->
      status = if tool.available, do: "✓", else: "✗"
      version = if tool.version, do: " (#{tool.version})", else: ""
      Logger.info("[Tools.Detector]   #{status} #{tool.display_name}#{version}")
    end)

    Logger.info("[Tools.Detector] Optional tools:")

    Enum.each(state.optional, fn tool ->
      status = if tool.available, do: "✓", else: "✗"
      version = if tool.version, do: " (#{tool.version})", else: ""
      Logger.info("[Tools.Detector]   #{status} #{tool.display_name}#{version}")
    end)

    available_count =
      Enum.count(state.core ++ state.optional, fn tool -> tool.available end)

    total_count = length(state.core) + length(state.optional)

    Logger.info("[Tools.Detector] Summary: #{available_count}/#{total_count} tools available")
  end
end
