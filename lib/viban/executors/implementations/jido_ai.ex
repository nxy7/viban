defmodule Viban.Executors.Implementations.JidoAI do
  @moduledoc """
  Executor implementation for Jido AI (API-based).

  Unlike CLI executors (Claude Code, Gemini), this executor uses the Anthropic API
  directly via jido_ai, with ReAct-style tool use on the Ash domain.

  Requires ANTHROPIC_API_KEY to be set.
  """

  @behaviour Viban.Executors.Behaviour

  require Logger

  @impl true
  def name, do: "Jido AI"

  @impl true
  def type, do: :jido_ai

  @impl true
  def available? do
    case Application.get_env(:viban, :anthropic_api_key) do
      nil ->
        Logger.debug("ANTHROPIC_API_KEY not configured - Jido AI unavailable")
        false

      "" ->
        Logger.debug("ANTHROPIC_API_KEY is empty - Jido AI unavailable")
        false

      _key ->
        true
    end
  end

  @impl true
  def build_command(prompt, opts) do
    model = Keyword.get(opts, :model, "anthropic:claude-sonnet-4-5-20250929")
    max_turns = Keyword.get(opts, :max_turns, 25)

    {:api,
     %{
       prompt: prompt,
       model: model,
       max_turns: max_turns,
       api_key: Application.get_env(:viban, :anthropic_api_key)
     }}
  end

  @impl true
  def default_opts do
    [
      model: "anthropic:claude-sonnet-4-5-20250929",
      max_turns: 25
    ]
  end

  @impl true
  def capabilities do
    [:streaming]
  end
end
