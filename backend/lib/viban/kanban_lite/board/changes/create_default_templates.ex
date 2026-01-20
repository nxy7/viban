defmodule Viban.KanbanLite.Board.Changes.CreateDefaultTemplates do
  @moduledoc """
  Creates default task templates when a new board is created (SQLite version).
  """

  use Ash.Resource.Change

  alias Viban.KanbanLite.TaskTemplate

  require Logger

  @default_templates [
    %{
      name: "Feature",
      position: 0,
      description_template: """
      ## Summary
      Brief description of the feature to implement.

      ## Requirements
      - [ ] Requirement 1
      - [ ] Requirement 2

      ## Acceptance Criteria
      - [ ] Criteria 1
      - [ ] Criteria 2
      """
    },
    %{
      name: "Bugfix",
      position: 1,
      description_template: """
      ## Bug Description
      What is happening vs what should happen.

      ## Steps to Reproduce
      1. Step 1
      2. Step 2

      ## Expected Behavior
      What should happen instead.

      ## Environment
      - OS:
      - Browser/Version:
      """
    },
    %{
      name: "Refactor",
      position: 2,
      description_template: """
      ## Current State
      Description of the current code/architecture.

      ## Proposed Changes
      What needs to be refactored and why.

      ## Goals
      - [ ] Improve readability
      - [ ] Improve performance
      - [ ] Reduce complexity

      ## Files Affected
      - file1
      - file2
      """
    },
    %{
      name: "Research",
      position: 3,
      description_template: """
      ## Research Question
      What do we need to find out?

      ## Context
      Why is this research needed?

      ## Areas to Explore
      - [ ] Area 1
      - [ ] Area 2

      ## Expected Output
      What should be delivered (document, POC, recommendation, etc.)
      """
    }
  ]

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, &create_default_templates/2)
  end

  defp create_default_templates(_changeset, board) do
    template_inputs =
      Enum.map(@default_templates, fn attrs ->
        Map.put(attrs, :board_id, board.id)
      end)

    case Ash.bulk_create(template_inputs, TaskTemplate, :create,
           return_errors?: true,
           return_records?: true,
           stop_on_error?: true
         ) do
      %Ash.BulkResult{status: :success} ->
        {:ok, board}

      %Ash.BulkResult{status: :error, errors: errors} ->
        Logger.error("Failed to create default templates for board #{board.id}: #{inspect(errors)}")
        {:ok, board}
    end
  end

  def default_templates, do: @default_templates
end
