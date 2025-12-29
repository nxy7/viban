defmodule Viban.Messages.TestMessage.Actions.Randomize do
  @moduledoc """
  Action to randomize the test message content.

  Selects a random message from a predefined list and either updates
  an existing message or creates a new one if none exists.
  """

  use Ash.Resource.Actions.Implementation

  @random_messages [
    "Hello from Viban!",
    "Phoenix Sync is working!",
    "Real-time updates are amazing!",
    "Elixir + SolidJS = Fast iteration!",
    "Ash Framework makes life easier!",
    "This message was randomly selected!",
    "End-to-end connectivity confirmed!",
    "The future of web development is here!",
    "Reactive data sync in action!",
    "Your tech stack is working perfectly!"
  ]

  @impl true
  def run(_input, _opts, _context) do
    random_text = Enum.random(@random_messages)

    case Ash.read(Viban.Messages.TestMessage) do
      {:ok, [existing | _]} ->
        Ash.update(existing, %{text: random_text})

      {:ok, []} ->
        Ash.create(Viban.Messages.TestMessage, %{text: random_text})

      {:error, error} ->
        {:error, error}
    end
  end
end
