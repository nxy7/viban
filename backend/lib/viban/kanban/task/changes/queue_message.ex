defmodule Viban.Kanban.Task.Changes.QueueMessage do
  @moduledoc """
  Ash change that appends a message to the task's message queue.

  Messages are queued for processing by the Execute AI hook. Each message
  includes the prompt, executor type, and optional image attachments.
  """

  use Ash.Resource.Change

  @impl true
  @spec change(Ash.Changeset.t(), keyword(), Ash.Resource.Change.context()) :: Ash.Changeset.t()
  def change(changeset, _opts, _context) do
    prompt = Ash.Changeset.get_argument(changeset, :prompt)
    executor_type = Ash.Changeset.get_argument(changeset, :executor_type) || :claude_code
    images = Ash.Changeset.get_argument(changeset, :images) || []
    current_queue = Ash.Changeset.get_data(changeset, :message_queue) || []

    if is_nil(prompt) or prompt == "" do
      Ash.Changeset.add_error(changeset, field: :prompt, message: "Prompt is required")
    else
      new_entry = %{
        "id" => Ash.UUID.generate(),
        "prompt" => prompt,
        "executor_type" => to_string(executor_type),
        "images" => images,
        "queued_at" => DateTime.utc_now() |> DateTime.to_iso8601()
      }

      updated_queue = current_queue ++ [new_entry]
      Ash.Changeset.change_attribute(changeset, :message_queue, updated_queue)
    end
  end
end
