defmodule Viban.KanbanLite.Message.Changes.AppendContent do
  @moduledoc """
  Appends content to an existing message (SQLite version).
  """

  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    new_content = Ash.Changeset.get_argument(changeset, :content)
    current_content = Ash.Changeset.get_data(changeset, :content) || ""

    Ash.Changeset.change_attribute(changeset, :content, current_content <> new_content)
  end
end
