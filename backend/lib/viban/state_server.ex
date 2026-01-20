defmodule Viban.StateServer do
  @moduledoc """
  Domain for StateServer persistence.

  Provides automatic state persistence for GenServers with the following features:

  - Async fire-and-forget writes to SQLite
  - Change detection to avoid unnecessary DB writes
  - Automatic lifecycle status management (:starting, :ok, :stopping, :stopped, :error)
  - Process death detection via Monitor

  ## Usage

  See `Viban.StateServer.Core` for usage instructions.
  """

  use Ash.Domain,
    otp_app: :viban

  alias Viban.StateServer.ActorState

  resources do
    resource ActorState
  end
end
