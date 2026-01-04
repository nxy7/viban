defmodule Viban.Kanban.Repository.Changes.AutoCloneLocalRepo do
  @moduledoc """
  Ash change that marks local repositories as already cloned.

  For repositories with `provider: :local`, the `clone_status` is
  automatically set to `:cloned` since there is no remote to clone from.
  The repository already exists on the local filesystem.
  """

  use Ash.Resource.Change

  @impl true
  @spec change(Ash.Changeset.t(), keyword(), Ash.Resource.Change.context()) :: Ash.Changeset.t()
  def change(changeset, _opts, _context) do
    provider = Ash.Changeset.get_attribute(changeset, :provider)

    if provider == :local do
      Ash.Changeset.force_change_attribute(changeset, :clone_status, :cloned)
    else
      changeset
    end
  end
end
