defmodule VibanWeb.RpcController do
  @moduledoc """
  RPC endpoint for Ash resource actions using AshTypescript.

  Delegates to AshTypescript.Rpc for action execution, which handles:
  - Action discovery by name across configured domains
  - Input/output field formatting
  - Field selection and pagination
  - Error formatting

  ## Request Format

  All requests are POST to `/api/rpc/run` with the following body:

      {
        "action": "create_task",
        "input": { ... },
        "identity": "uuid",  // For update/destroy actions
        "fields": ["id", "title"]  // Optional field selection
      }

  ## Response Format

  Success:
      {"success": true, "data": { ... }}

  Error:
      {"success": false, "errors": [...]}
  """

  use VibanWeb, :controller

  @doc """
  Handles RPC calls to Ash resources via AshTypescript.
  """
  @spec run(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def run(conn, params) do
    result = AshTypescript.Rpc.run_action(:viban, conn, params)
    json(conn, result)
  end

  @doc """
  Validates action parameters without execution.
  Used for form validation in the client.
  """
  @spec validate(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def validate(conn, params) do
    result = AshTypescript.Rpc.validate_action(:viban, conn, params)
    json(conn, result)
  end
end
