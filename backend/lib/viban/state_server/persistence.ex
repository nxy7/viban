defmodule Viban.StateServer.Persistence do
  @moduledoc """
  Async persistence for StateServer state.

  Uses fire-and-forget spawns for DB writes to avoid blocking the GenServer.
  Failures are logged but do not affect the calling process.
  """

  require Logger

  alias Viban.StateServer.ActorState
  alias Viban.StateServer.Serializer

  @spec save_async(module(), String.t(), struct() | map()) :: :ok
  def save_async(actor_module, actor_id, state) do
    serialized = Serializer.serialize(state)
    actor_type = to_string(actor_module)

    spawn(fn ->
      try do
        case ActorState.get_by_actor(actor_type, actor_id) do
          {:ok, record} ->
            ActorState.save_state(record, %{state: serialized})

          {:error, _} ->
            ActorState.upsert(%{
              actor_type: actor_type,
              actor_id: actor_id,
              state: serialized,
              status: :ok
            })
        end
      rescue
        e ->
          Logger.error(
            "[StateServer] Exception persisting state for #{actor_type}:#{actor_id}: #{Exception.message(e)}"
          )
      end
    end)

    :ok
  end

  @spec save_with_status_async(module(), String.t(), struct() | map(), atom()) :: :ok
  def save_with_status_async(actor_module, actor_id, state, status) do
    serialized = Serializer.serialize(state)
    actor_type = to_string(actor_module)

    spawn(fn ->
      try do
        case ActorState.upsert(%{
               actor_type: actor_type,
               actor_id: actor_id,
               state: serialized,
               status: status
             }) do
          {:ok, _} ->
            :ok

          {:error, reason} ->
            Logger.warning(
              "[StateServer] Failed to persist state for #{actor_type}:#{actor_id}: #{inspect(reason)}"
            )
        end
      rescue
        e ->
          Logger.error(
            "[StateServer] Exception persisting state for #{actor_type}:#{actor_id}: #{Exception.message(e)}"
          )
      end
    end)

    :ok
  end

  @spec update_status_async(module(), String.t(), atom(), String.t() | nil) :: :ok
  def update_status_async(actor_module, actor_id, status, message) do
    actor_type = to_string(actor_module)

    spawn(fn ->
      try do
        case ActorState.get_by_actor(actor_type, actor_id) do
          {:ok, record} ->
            ActorState.update_status(record, %{status: status, message: message})

          {:error, error} when is_struct(error, Ash.Error.Invalid) or is_struct(error, Ash.Error.Query.NotFound) ->
            ActorState.upsert(%{
              actor_type: actor_type,
              actor_id: actor_id,
              state: %{},
              status: status,
              message: message
            })

          {:error, reason} ->
            Logger.warning(
              "[StateServer] Failed to update status for #{actor_type}:#{actor_id}: #{inspect(reason)}"
            )
        end
      rescue
        e ->
          Logger.error(
            "[StateServer] Exception updating status for #{actor_type}:#{actor_id}: #{Exception.message(e)}"
          )
      end
    end)

    :ok
  end

  @spec load(module(), String.t()) :: {:ok, map()} | :not_found
  def load(actor_module, actor_id) do
    actor_type = to_string(actor_module)

    case ActorState.get_by_actor(actor_type, actor_id) do
      {:ok, %{state: state}} ->
        {:ok, Serializer.deserialize(state, actor_module)}

      {:error, _} ->
        :not_found
    end
  end

  @spec delete_async(module(), String.t()) :: :ok
  def delete_async(actor_module, actor_id) do
    actor_type = to_string(actor_module)

    spawn(fn ->
      case ActorState.get_by_actor(actor_type, actor_id) do
        {:ok, record} ->
          ActorState.destroy(record)

        _ ->
          :ok
      end
    end)

    :ok
  end
end
