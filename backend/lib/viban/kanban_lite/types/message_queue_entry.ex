defmodule Viban.KanbanLite.Types.MessageQueueEntry do
  @moduledoc """
  Embedded resource for message queue entries (SQLite version).
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
    end

    attribute :executor_type, :atom do
      allow_nil? false
      public? true
      default :claude_code
      constraints one_of: [:claude_code, :gemini_cli]
    end

    attribute :images, {:array, :map} do
      public? true
      default []
    end

    attribute :queued_at, :string do
      allow_nil? false
      public? true
    end
  end
end
