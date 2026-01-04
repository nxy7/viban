defmodule Viban.Kanban.Repository.Changes.SetFullNameFromName do
  @moduledoc """
  Ash change that sets `full_name` from `name` for local repositories.

  When creating or updating a repository:
  - If `full_name` is not provided (nil or empty string)
  - Then `full_name` is set to the same value as `name`

  This ensures local repositories have consistent naming without
  requiring the client to provide redundant data.
  """

  use Ash.Resource.Change

  @impl true
  @spec change(Ash.Changeset.t(), keyword(), Ash.Resource.Change.context()) :: Ash.Changeset.t()
  def change(changeset, _opts, _context) do
    full_name = Ash.Changeset.get_attribute(changeset, :full_name)

    if full_name in [nil, ""] do
      name = Ash.Changeset.get_attribute(changeset, :name)
      Ash.Changeset.force_change_attribute(changeset, :full_name, name)
    else
      changeset
    end
  end
end
