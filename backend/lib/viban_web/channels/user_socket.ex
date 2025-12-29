defmodule VibanWeb.UserSocket do
  @moduledoc """
  User socket for Phoenix Channels.

  Handles WebSocket connections for real-time features including
  task chat and LLM streaming.
  """

  use Phoenix.Socket

  # Channels
  channel "task:*", VibanWeb.TaskChannel
  channel "board:*", VibanWeb.BoardChannel

  @impl true
  def connect(_params, socket, _connect_info) do
    # For MVP, allow all connections
    # Future: Add authentication via token or session
    {:ok, socket}
  end

  @impl true
  def id(_socket) do
    # For MVP, no user-specific identification
    # Future: Return user ID for targeted messaging
    nil
  end
end
