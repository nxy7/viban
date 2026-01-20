defmodule Viban.Kanban.Column.Changes.MergeSettings do
  @moduledoc """
  Merges new settings with existing column settings (shallow merge).
  """

  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    new_settings = Ash.Changeset.get_argument(changeset, :settings)
    current_settings = Ash.Changeset.get_attribute(changeset, :settings) || %{}

    merged_settings = Map.merge(current_settings, new_settings)

    Ash.Changeset.force_change_attribute(changeset, :settings, merged_settings)
  end
end
