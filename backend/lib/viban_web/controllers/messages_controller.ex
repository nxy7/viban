defmodule VibanWeb.MessagesController do
  @moduledoc """
  API endpoints for test message management.

  This controller provides endpoints for interacting with test messages,
  primarily used for development and testing of the Electric sync functionality.

  ## Endpoints

  - `POST /api/messages/randomize` - Generate a new random test message
  """

  use VibanWeb, :controller

  import VibanWeb.ControllerHelpers, only: [json_ok: 2, json_error: 3]

  alias Viban.Messages.TestMessage

  require Logger

  @doc """
  Generates a random test message.

  Creates a new test message with random content using the `randomize` action
  on the TestMessage resource. Useful for testing real-time sync.

  ## Response

  Returns the newly created message with its ID, text, and timestamps.
  """
  @spec randomize(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def randomize(conn, _params) do
    action_input = Ash.ActionInput.for_action(TestMessage, :randomize, %{})

    case Ash.run_action(action_input) do
      {:ok, message} ->
        Logger.debug("[MessagesController] Created random message: #{message.id}")

        json_ok(conn, %{
          result: %{
            id: message.id,
            text: message.text,
            inserted_at: message.inserted_at,
            updated_at: message.updated_at
          }
        })

      {:error, error} ->
        Logger.warning("[MessagesController] Failed to create random message: #{inspect(error)}")
        json_error(conn, :unprocessable_entity, inspect(error))
    end
  end
end
