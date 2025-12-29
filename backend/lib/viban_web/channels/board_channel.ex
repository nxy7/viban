defmodule VibanWeb.BoardChannel do
  @moduledoc """
  Phoenix Channel for board-level events.

  Handles real-time communication for board-wide events like client actions
  triggered by hooks.

  ## Topics

  - `board:{board_id}` - Board-specific events

  ## Events

  ### Outgoing (server -> client)
  - `client_action` - Action to be executed by the client
    - `type: "play-sound"` - Play a notification sound
      - `sound: string` - Sound type to play (e.g., "ding", "bell")
  """

  use Phoenix.Channel

  alias VibanWeb.Endpoint

  require Logger

  @impl true
  def join("board:" <> board_id, _params, socket) do
    Logger.debug("[BoardChannel] Client joined board:#{board_id}")
    {:ok, assign(socket, :board_id, board_id)}
  end

  @doc """
  Broadcasts a client action to all subscribers of a board channel.

  ## Parameters
  - `board_id` - The board ID to broadcast to
  - `action_type` - The type of client action (e.g., "play-sound")
  - `payload` - Additional data for the action

  ## Example

      BoardChannel.broadcast_client_action(board_id, "play-sound", %{sound: "ding"})
  """
  @spec broadcast_client_action(String.t(), String.t(), map()) :: :ok
  def broadcast_client_action(board_id, action_type, payload \\ %{}) do
    topic = "board:#{board_id}"
    message = Map.merge(payload, %{type: action_type})

    Logger.info("[BoardChannel] Broadcasting client_action to #{topic}: #{inspect(message)}")

    Endpoint.broadcast!(topic, "client_action", message)
    :ok
  end
end
