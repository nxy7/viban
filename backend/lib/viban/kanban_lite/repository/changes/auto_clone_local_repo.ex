defmodule Viban.KanbanLite.Repository.Changes.AutoCloneLocalRepo do
  @moduledoc """
  Auto-marks local repositories as cloned (SQLite version).
  """

  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    provider = Ash.Changeset.get_attribute(changeset, :provider)
    local_path = Ash.Changeset.get_attribute(changeset, :local_path)

    if provider == :local and not is_nil(local_path) and File.dir?(local_path) do
      changeset
      |> Ash.Changeset.change_attribute(:clone_status, :cloned)
    else
      changeset
    end
  end
end
