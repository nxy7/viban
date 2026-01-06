defmodule Viban.StateServer do
  @moduledoc """
  Domain for StateServer persistence.

  Provides automatic state persistence for GenServers with the following features:

  - Async fire-and-forget writes to PostgreSQL
  - Change detection to avoid unnecessary DB writes
  - Automatic lifecycle status management (:starting, :ok, :stopping, :stopped, :error)
  - Process death detection via Monitor
  - Automatic sync to frontend via Electric SQL

  ## Usage

  See `Viban.StateServer.Core` for usage instructions.
  """

  use Ash.Domain,
    extensions: [AshSync, AshTypescript.Rpc],
    otp_app: :viban

  alias Viban.StateServer.ActorState

  sync do
    resource ActorState do
      query(:sync_actor_states, :read)
    end
  end

  resources do
    resource ActorState
  end

  typescript_rpc do
    resource ActorState do
      rpc_action(:set_demo_text, :set_demo_text)
    end
  end
end
