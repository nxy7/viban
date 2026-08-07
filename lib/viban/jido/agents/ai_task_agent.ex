defmodule Viban.Jido.Agents.AITaskAgent do
  @moduledoc """
  AI agent using Jido.AI with ReAct strategy for autonomous task execution.

  Uses tools from AshJido (Ash resource actions) and Jido Actions (system hooks)
  to interact with the Kanban board.

  ## Tool Loading

  Static hook tools are defined at compile time. AshJido-generated tools are
  loaded at runtime via `all_tools/0` and passed as request-scoped overrides
  when calling `ask_sync/3`.
  """

  use Jido.AI.Agent,
    name: "ai_task_agent",
    description: "AI-powered task agent using LLM for autonomous Kanban task execution",
    tags: ["ai", "llm", "task", "autonomous"],
    tools: [
      Viban.Jido.Actions.MoveTask,
      Viban.Jido.Actions.PlaySound
    ],
    model: :capable,
    max_iterations: 25,
    max_tokens: 4096,
    streaming: false,
    system_prompt: """
    You are an AI task agent for a Kanban board application called Viban.
    You can interact with the board by creating, updating, moving, and deleting tasks and columns.
    You can also play sounds and move tasks between columns using the available tools.
    Always explain what you're doing before taking actions.
    """

  def all_tools do
    ash_tools() ++ hook_tools()
  end

  defp ash_tools do
    AshJido.Tools.actions(Viban.Kanban.Task) ++
      AshJido.Tools.actions(Viban.Kanban.Column)
  end

  defp hook_tools do
    [
      Viban.Jido.Actions.MoveTask,
      Viban.Jido.Actions.PlaySound
    ]
  end
end
