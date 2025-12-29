defmodule Viban.Kanban.Message.Changes.AppendContent do
  @moduledoc """
  Ash change that appends new content to the existing message content.

  Used for streaming responses where content is received in chunks.
  Properly handles nil values by treating them as empty strings.

  ## Example

  A message with content "Hello" that receives an append_content action
  with argument `content: " World"` will result in content "Hello World".
  """

  use Ash.Resource.Change

  @impl true
  @spec change(Ash.Changeset.t(), keyword(), Ash.Resource.Change.context()) :: Ash.Changeset.t()
  def change(changeset, _opts, _context) do
    new_content = Ash.Changeset.get_argument(changeset, :content) || ""
    current_content = Ash.Changeset.get_attribute(changeset, :content) || ""
    Ash.Changeset.change_attribute(changeset, :content, current_content <> new_content)
  end
end
