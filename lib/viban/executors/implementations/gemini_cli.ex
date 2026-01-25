defmodule Viban.Executors.Implementations.GeminiCLI do
  @moduledoc """
  Executor implementation for Google's Gemini CLI.

  Gemini CLI is Google's command-line tool for AI-assisted coding.
  It's installed via npm: `npx @google/gemini-cli`

  ## Usage

  The executor runs Gemini CLI with automatic mode (yolo) enabled,
  which allows it to execute shell commands without prompting.
  """

  @behaviour Viban.Executors.Behaviour

  require Logger

  @gemini_package "@google/gemini-cli"
  @gemini_version "0.21.1"

  @impl true
  def name, do: "Gemini CLI"

  @impl true
  def type, do: :gemini_cli

  @impl true
  def available? do
    case System.find_executable("gemini") do
      nil ->
        Logger.debug("gemini not found in PATH - Gemini CLI unavailable")
        false

      _path ->
        true
    end
  end

  @impl true
  def build_command(prompt, opts) do
    model = Keyword.get(opts, :model)
    yolo_mode = Keyword.get(opts, :yolo_mode, true)

    args =
      ["-y", "#{@gemini_package}@#{@gemini_version}"]
      |> maybe_add_arg(model, "--model")
      |> maybe_add_yolo_args(yolo_mode)
      |> Kernel.++([prompt])

    {"npx", args}
  end

  @impl true
  def default_opts do
    [
      yolo_mode: true,
      model: nil
    ]
  end

  @impl true
  def capabilities do
    [:streaming]
  end

  @impl true
  def parse_output(raw) do
    # Gemini CLI outputs plain text, no special parsing needed
    {:raw, raw}
  end

  @impl true
  def env do
    []
  end

  defp maybe_add_arg(args, nil, _flag), do: args
  defp maybe_add_arg(args, value, flag), do: args ++ [flag, value]

  defp maybe_add_yolo_args(args, false), do: args

  defp maybe_add_yolo_args(args, true) do
    args ++ ["--yolo", "--allowed-tools", "run_shell_command"]
  end
end
