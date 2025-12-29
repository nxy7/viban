defmodule Viban.Kanban.Column.Changes.MergeSettings do
  @moduledoc """
  Ash change that performs a shallow merge of column settings.

  This ensures existing settings are preserved when updating,
  rather than being completely replaced. New keys are added and
  existing keys are updated with new values.

  ## Example

      # Current settings: %{max_concurrent_tasks: 3, hooks_enabled: true}
      # New settings: %{max_concurrent_tasks: 5, color_scheme: "dark"}
      # Result: %{max_concurrent_tasks: 5, hooks_enabled: true, color_scheme: "dark"}
  """

  use Ash.Resource.Change

  @impl true
  @spec change(Ash.Changeset.t(), keyword(), Ash.Resource.Change.context()) :: Ash.Changeset.t()
  def change(changeset, _opts, _context) do
    new_settings = Ash.Changeset.get_argument(changeset, :settings) || %{}
    current_settings = Ash.Changeset.get_data(changeset, :settings) || %{}

    merged = Map.merge(current_settings, new_settings)
    Ash.Changeset.change_attribute(changeset, :settings, merged)
  end
end
