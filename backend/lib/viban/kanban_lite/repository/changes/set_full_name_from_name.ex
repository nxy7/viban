defmodule Viban.KanbanLite.Repository.Changes.SetFullNameFromName do
  @moduledoc """
  Sets full_name from name for local repositories (SQLite version).
  """

  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    provider = Ash.Changeset.get_attribute(changeset, :provider)
    full_name = Ash.Changeset.get_attribute(changeset, :full_name)
    name = Ash.Changeset.get_attribute(changeset, :name)

    if provider == :local and is_nil(full_name) and not is_nil(name) do
      Ash.Changeset.change_attribute(changeset, :full_name, name)
    else
      changeset
    end
  end
end
