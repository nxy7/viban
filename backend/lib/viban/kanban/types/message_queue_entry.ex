defmodule Viban.Kanban.Types.MessageQueueEntry do
  @moduledoc """
  Embedded resource for message queue entries.

  Represents a message queued for AI execution, including optional image attachments.
  """
  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute :id, :string do
      allow_nil? false
      primary_key? true
      public? true
    end

    attribute :prompt, :string do
      allow_nil? false
      public? true
      description "The user's message/prompt"
    end

    attribute :executor_type, :atom do
      allow_nil? false
      public? true
      default :claude_code
      constraints one_of: [:claude_code, :gemini_cli]
      description "The executor to use for this message"
    end

    attribute :images, {:array, :map} do
      public? true
      default []
      description "Image attachments: [{name, data, mimeType}]"
    end

    attribute :queued_at, :string do
      allow_nil? false
      public? true
      description "ISO8601 timestamp when message was queued"
    end
  end
end
