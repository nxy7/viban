defmodule Viban.Executors.Behaviour do
  @moduledoc """
  Behaviour definition for executor implementations.

  An executor is responsible for running AI coding agents (CLI tools or API-based)
  and streaming their output back to the application.

  ## Implementing an Executor

      defmodule MyApp.Executors.ClaudeCode do
        @behaviour Viban.Executors.Behaviour

        @impl true
        def name, do: "Claude Code"

        @impl true
        def type, do: :claude_code

        @impl true
        def available? do
          case System.find_executable("claude") do
            nil -> false
            _path -> true
          end
        end

        @impl true
        def build_command(prompt, opts) do
          working_dir = Keyword.get(opts, :working_directory, ".")
          {"claude", ["-p", prompt, "--output-format", "stream-json"]}
        end

        # ...
      end
  """

  @type capability :: :streaming | :interactive | :mcp_support | :follow_up
  @type executor_type ::
          :claude_code | :gemini_cli | :codex | :opencode | :api_anthropic | :api_openai
  @type output_event ::
          {:stdout, binary()}
          | {:stderr, binary()}
          | {:exit, integer()}
          | {:error, term()}

  @doc """
  Human-readable name of the executor.
  """
  @callback name() :: String.t()

  @doc """
  Atom identifier for the executor type.
  """
  @callback type() :: executor_type()

  @doc """
  Check if this executor is available on the current system.
  For CLI executors, this typically checks if the executable exists.
  For API executors, this might check for configured credentials.
  """
  @callback available?() :: boolean()

  @doc """
  Build the command to execute.
  Returns a tuple of {executable, arguments}.
  For API-based executors, this might return a special marker.
  """
  @callback build_command(prompt :: String.t(), opts :: keyword()) ::
              {executable :: String.t(), args :: [String.t()]} | {:api, config :: map()}

  @doc """
  Default options for this executor.
  """
  @callback default_opts() :: keyword()

  @doc """
  List of capabilities this executor supports.
  - :streaming - Can stream output in real-time
  - :interactive - Supports interactive input/output
  - :mcp_support - Supports MCP server configuration
  - :follow_up - Supports follow-up prompts in same session
  """
  @callback capabilities() :: [capability()]

  @doc """
  Parse raw output from the executor into structured events.
  This is used for executors that output structured data (like stream-json).
  """
  @callback parse_output(raw :: binary()) :: {:ok, parsed :: term()} | {:raw, binary()}

  @doc """
  Environment variables to set when running the executor.
  """
  @callback env() :: [{String.t(), String.t()}]

  @optional_callbacks [parse_output: 1, env: 0]
end
