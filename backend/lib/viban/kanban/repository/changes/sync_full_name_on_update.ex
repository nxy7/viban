defmodule Viban.Kanban.Repository.Changes.SyncFullNameOnUpdate do
  @moduledoc """
  Ash change that keeps `full_name` in sync with `name` for local repositories.

  When updating a repository:
  - If `name` is being changed
  - And `full_name` is NOT being explicitly changed
  - And the provider is `:local`
  - Then `full_name` is updated to match the new `name`

  This maintains consistency for local repositories where `name` and
  `full_name` should always be the same.
  """

  use Ash.Resource.Change

  @impl true
  @spec change(Ash.Changeset.t(), keyword(), Ash.Resource.Change.context()) :: Ash.Changeset.t()
  def change(changeset, _opts, _context) do
    name_changing = Ash.Changeset.changing_attribute?(changeset, :name)
    full_name_changing = Ash.Changeset.changing_attribute?(changeset, :full_name)
    provider = changeset.data.provider

    if name_changing && !full_name_changing && provider == :local do
      name = Ash.Changeset.get_attribute(changeset, :name)
      Ash.Changeset.force_change_attribute(changeset, :full_name, name)
    else
      changeset
    end
  end
end
