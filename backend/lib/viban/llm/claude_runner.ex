defmodule Viban.LLM.ClaudeRunner do
  @moduledoc """
  Utility module for running Claude Code CLI for simple, non-interactive tasks.

  This module provides a simplified interface for one-shot Claude CLI executions,
  handling PTY requirements, timeouts, and output cleaning.

  ## Usage

      # Run with default options (sonnet model, 60s timeout)
      {:ok, output} = ClaudeRunner.run("Summarize this code")

      # Run with custom options
      {:ok, output} = ClaudeRunner.run("Analyze this", model: "haiku", timeout_ms: 30_000)

  ## Options

  - `:model` - Claude model to use (default: "sonnet")
  - `:timeout_ms` - Timeout in milliseconds (default: 60_000)
  - `:clean_output` - Whether to clean ANSI codes from output (default: true)
  """

  require Logger

  alias Viban.LLM.AnsiCleaner
  alias Viban.Executors.Implementations.ClaudeCode

  @default_timeout_ms 60_000
  @default_model "sonnet"

  @type run_option ::
          {:model, String.t()}
          | {:timeout_ms, pos_integer()}
          | {:clean_output, boolean()}

  @doc """
  Runs Claude Code CLI with the given prompt and options.

  Returns `{:ok, output}` on success or `{:error, reason}` on failure.
  """
  @spec run(String.t(), [run_option()]) :: {:ok, String.t()} | {:error, String.t()}
  def run(prompt, opts \\ []) do
    model = Keyword.get(opts, :model, @default_model)
    timeout_ms = Keyword.get(opts, :timeout_ms, @default_timeout_ms)
    clean_output = Keyword.get(opts, :clean_output, true)

    case find_claude_executable() do
      {:ok, claude_path} ->
        execute_claude(claude_path, prompt, model, timeout_ms, clean_output)

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Checks if Claude Code CLI is available on the system.
  """
  @spec available?() :: boolean()
  def available? do
    ClaudeCode.find_claude_executable() != nil
  end

  # Private functions

  defp find_claude_executable do
    case ClaudeCode.find_claude_executable() do
      nil -> {:error, "Claude Code CLI not found"}
      path -> {:ok, path}
    end
  end

  defp execute_claude(claude_path, prompt, model, timeout_ms, clean_output) do
    Logger.info("[ClaudeRunner] Running Claude Code CLI with #{model} model")
    Logger.debug("[ClaudeRunner] Prompt: #{String.slice(prompt, 0, 100)}...")

    args = build_args(prompt, model)
    {script_cmd, script_args} = build_pty_command(claude_path, args)

    Logger.debug("[ClaudeRunner] Running via script: #{script_cmd}")

    task =
      Task.async(fn ->
        System.cmd(script_cmd, script_args, stderr_to_stdout: true)
      end)

    case Task.yield(task, timeout_ms) || Task.shutdown(task) do
      {:ok, {output, 0}} ->
        result = if clean_output, do: AnsiCleaner.clean(output), else: output
        Logger.debug("[ClaudeRunner] Output: #{String.slice(result, 0, 200)}...")
        {:ok, result}

      {:ok, {output, exit_code}} ->
        Logger.error("[ClaudeRunner] Failed with exit code #{exit_code}: #{output}")
        {:error, "Claude Code failed with exit code #{exit_code}"}

      nil ->
        Logger.error("[ClaudeRunner] Timed out after #{timeout_ms}ms")
        {:error, "Claude Code timed out"}
    end
  end

  defp build_args(prompt, model) do
    [
      "-p",
      prompt,
      "--output-format",
      "text",
      "--model",
      model,
      "--no-session-persistence",
      "--dangerously-skip-permissions"
    ]
  end

  defp build_pty_command(claude_path, args) do
    # Use script to provide PTY (required for Claude Code streaming output)
    # macOS and Linux have different syntax for the script command
    case :os.type() do
      {:unix, :darwin} ->
        # macOS: script -q /dev/null <cmd> <args...>
        {"/usr/bin/script", ["-q", "/dev/null", claude_path] ++ args}

      {:unix, _} ->
        # Linux: script -q -c "<cmd> <args...>" /dev/null
        cmd_string = Enum.join([claude_path | args], " ")
        {"/usr/bin/script", ["-q", "-c", cmd_string, "/dev/null"]}

      _ ->
        # Fallback - no PTY wrapper (may not work properly)
        {claude_path, args}
    end
  end
end
