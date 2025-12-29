defmodule Viban.Messages.TestMessage.Actions.GetOrCreate do
  @moduledoc """
  Action to get an existing test message or create a new one if none exists.

  This ensures there's always at least one test message available
  for the real-time sync demonstration.
  """

  use Ash.Resource.Actions.Implementation

  @default_message "Hello from Viban!"

  @impl true
  def run(_input, _opts, _context) do
    case Ash.read(Viban.Messages.TestMessage) do
      {:ok, [existing | _]} ->
        {:ok, existing}

      {:ok, []} ->
        Ash.create(Viban.Messages.TestMessage, %{text: @default_message})

      {:error, error} ->
        {:error, error}
    end
  end
end
