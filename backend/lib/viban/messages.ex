defmodule Viban.Messages do
  @moduledoc """
  Domain for system test messages.

  This domain provides a simple message resource for testing
  real-time sync functionality between the frontend and backend.

  ## Resources

  - `Viban.Messages.TestMessage` - Simple test messages for connectivity verification
  """

  use Ash.Domain,
    extensions: [AshTypescript.Domain]

  resources do
    resource Viban.Messages.TestMessage
  end
end
