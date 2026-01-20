defmodule Viban.Kanban.Repository.Changes.SyncFullNameOnUpdate do
  @moduledoc """
  Syncs full_name when name is updated for local repos (SQLite version).
  """

  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    provider = Ash.Changeset.get_data(changeset, :provider)

    if provider == :local and Ash.Changeset.changing_attribute?(changeset, :name) do
      name = Ash.Changeset.get_attribute(changeset, :name)
      Ash.Changeset.change_attribute(changeset, :full_name, name)
    else
      changeset
    end
  end
end
