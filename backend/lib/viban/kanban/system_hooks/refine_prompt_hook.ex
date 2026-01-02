defmodule Viban.Kanban.SystemHooks.RefinePromptHook do
  @moduledoc """
  System hook that uses AI to automatically improve the task description
  with success criteria, clear requirements, and proper markdown formatting.
  """

  @behaviour Viban.Kanban.SystemHooks.Behaviour

  require Logger

  @impl true
  def id, do: "system:refine-prompt"

  @impl true
  def name, do: "Auto-Refine Task Description"

  @impl true
  def description do
    "Uses AI to automatically improve the task description with success criteria, " <>
      "clear requirements, and proper markdown formatting when the task enters this column."
  end

  @impl true
  def execute(task, _column, _opts) do
    # Skip if already has a well-structured description (> 500 chars suggests it's already refined)
    if task.description && String.length(task.description) > 500 do
      Logger.info("[RefinePromptHook] Task #{task.id} already has detailed description, skipping")
      :ok
    else
      Logger.info("[RefinePromptHook] Queueing prompt refinement for task #{task.id}")
      :ok
    end
  end
end
