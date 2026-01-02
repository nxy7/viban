defmodule Viban.Executors.Implementations.ClaudeCode do
  @moduledoc """
  Executor implementation for Claude Code CLI.

  Claude Code is Anthropic's official CLI tool for agentic coding.
  It requires the user to have `claude` installed and authenticated.

  ## Usage

  The executor runs Claude Code in print mode (`-p`) with streaming JSON output,
  which provides structured events that can be parsed and displayed in real-time.

  ## Configuration

  No API keys needed - Claude Code handles authentication via its own config.
  """

  @behaviour Viban.Executors.Behaviour

  require Logger

  @impl true
  def name, do: "Claude Code"

  @impl true
  def type, do: :claude_code

  @impl true
  def available? do
    case find_claude_executable() do
      nil ->
        Logger.debug("Claude Code CLI not found in PATH or common locations")
        false

      path ->
        Logger.debug("Claude Code CLI found at: #{path}")
        true
    end
  end

  @doc """
  Wrap a command with PTY for proper TTY handling.
  Claude Code requires a TTY for streaming output.
  """
  def wrap_with_pty(executable, args) do
    case :os.type() do
      {:unix, :darwin} ->
        {"/usr/bin/script", ["-q", "/dev/null", executable] ++ args}

      {:unix, _} ->
        cmd_string = Enum.join([executable | args], " ")
        {"/usr/bin/script", ["-q", "-c", cmd_string, "/dev/null"]}

      _ ->
        {executable, args}
    end
  end

  @doc """
  Find the claude executable, checking both PATH and common installation locations.
  """
  def find_claude_executable do
    # First try PATH
    case System.find_executable("claude") do
      nil -> check_common_locations()
      path -> path
    end
  end

  defp check_common_locations do
    home = System.get_env("HOME") || "~"

    common_paths = [
      # Nix profile
      Path.join([home, ".nix-profile", "bin", "claude"]),
      # npm global
      Path.join([home, ".npm-global", "bin", "claude"]),
      # Homebrew (macOS)
      "/opt/homebrew/bin/claude",
      "/usr/local/bin/claude",
      # User local bin
      Path.join([home, ".local", "bin", "claude"]),
      # Cargo bin (if installed via cargo)
      Path.join([home, ".cargo", "bin", "claude"])
    ]

    Enum.find(common_paths, fn path ->
      File.exists?(path) and File.stat!(path).type == :regular
    end)
  end

  @impl true
  def build_command(prompt, opts) do
    working_dir = Keyword.get(opts, :working_directory)
    max_turns = Keyword.get(opts, :max_turns, 50)
    skip_permissions = Keyword.get(opts, :skip_permissions, true)
    system_prompt = Keyword.get(opts, :system_prompt)
    mcp_config = Keyword.get(opts, :mcp_config)

    claude_executable = find_claude_executable() || "claude"

    claude_args =
      ["-p", prompt]
      |> add_arg("--output-format", "stream-json")
      |> add_flag("--verbose")
      |> add_arg("--max-turns", to_string(max_turns))
      |> maybe_add_flag(skip_permissions, "--dangerously-skip-permissions")
      |> maybe_add_arg(system_prompt, "--append-system-prompt")
      |> maybe_add_arg(mcp_config, "--mcp-config")
      |> maybe_add_arg(working_dir, "--add-dir")

    wrap_with_pty(claude_executable, claude_args)
  end

  @impl true
  def default_opts do
    [
      max_turns: 50,
      skip_permissions: true,
      output_format: :stream_json
    ]
  end

  @impl true
  def capabilities do
    [:streaming, :mcp_support, :follow_up]
  end

  @impl true
  def parse_output(raw) do
    cleaned = strip_ansi_sequences(raw)

    if String.trim(cleaned) == "" do
      :skip
    else
      case Jason.decode(cleaned) do
        {:ok, parsed} ->
          {:ok, normalize_event(parsed)}

        {:error, _reason} ->
          :skip
      end
    end
  end

  defp strip_ansi_sequences(str) do
    str
    |> String.replace(~r/\e\[[0-9;?]*[a-zA-Z]/, "")
    |> String.replace(~r/\e\][^\a]*\a/, "")
    |> String.replace(~r/\e[PX^_][^\e]*\e\\/, "")
    |> String.replace(~r/[\x00-\x08\x0B\x0C\x0E-\x1F]/, "")
  end

  @impl true
  def env do
    # Claude Code respects these environment variables
    [
      {"CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC", "1"}
    ]
  end

  # Normalize stream-json events into our internal format
  defp normalize_event(%{"type" => "assistant", "message" => message}) do
    %{
      type: :assistant_message,
      content: extract_content(message),
      raw: message
    }
  end

  defp normalize_event(%{"type" => "result", "result" => result}) do
    %{
      type: :result,
      content: result,
      raw: result
    }
  end

  defp normalize_event(%{"type" => "tool_use", "name" => "TodoWrite"} = event) do
    # Special handling for TodoWrite tool - extract the todos
    input = Map.get(event, "input", %{})
    todos = Map.get(input, "todos", [])

    %{
      type: :todo_update,
      tool: "TodoWrite",
      todos: todos,
      raw: event
    }
  end

  defp normalize_event(%{"type" => "tool_use", "name" => name} = event) do
    %{
      type: :tool_use,
      tool: name,
      input: Map.get(event, "input"),
      raw: event
    }
  end

  defp normalize_event(%{"type" => "tool_result"} = event) do
    %{
      type: :tool_result,
      content: Map.get(event, "content"),
      raw: event
    }
  end

  defp normalize_event(%{"type" => "error", "error" => error}) do
    %{
      type: :error,
      message: error,
      raw: error
    }
  end

  defp normalize_event(event) do
    Logger.warning(
      "[ClaudeCode] Unknown event type, logging for future handling: #{inspect(event)}"
    )

    %{
      type: :unknown,
      raw: event
    }
  end

  defp extract_content(%{"content" => content}) when is_list(content) do
    content
    |> Enum.map(fn
      %{"type" => "text", "text" => text} -> text
      %{"text" => text} -> text
      other -> inspect(other)
    end)
    |> Enum.join("")
  end

  defp extract_content(%{"content" => content}) when is_binary(content), do: content
  defp extract_content(_), do: ""

  # Helper functions for building command arguments
  defp add_arg(args, flag, value) do
    args ++ [flag, value]
  end

  defp add_flag(args, flag) do
    args ++ [flag]
  end

  defp maybe_add_arg(args, nil, _flag), do: args
  defp maybe_add_arg(args, value, flag), do: args ++ [flag, value]

  defp maybe_add_flag(args, false, _flag), do: args
  defp maybe_add_flag(args, true, flag), do: args ++ [flag]
end
