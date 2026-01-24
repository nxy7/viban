defmodule Viban.Kanban.HookExecution.HookNotifier do
  @moduledoc """
  Broadcasts hook execution events to clients via Phoenix PubSub.

  Provides a centralized, server-centric way for hooks to broadcast their
  execution and effects to all connected clients.

  ## Event Structure

  Hook events are broadcast with the following structure:

      {:hook_executed, %{
        hook_id: "system:play-sound",
        hook_name: "Play Sound",
        task_id: "uuid",
        triggering_column_id: "uuid",  # Column that triggered the hook
        result: :ok | :error,
        effects: %{...}  # Hook-specific effects
      }}

  ## Usage

  Hooks should call `broadcast_hook_executed/3` when they complete:

      HookNotifier.broadcast_hook_executed(
        board_id,
        execution,
        effects: %{play_sound: %{sound: "ding"}}
      )
  """

  require Logger

  @doc """
  Broadcasts a hook execution event to all clients on a board.

  ## Parameters

  - `board_id` - The board to broadcast to
  - `execution` - The HookExecution struct
  - `opts` - Options including:
    - `:effects` - Map of effects produced by the hook
    - `:result` - `:ok` or `:error` (default: `:ok`)
  """
  @spec broadcast_hook_executed(String.t(), %Viban.Kanban.HookExecution{}, keyword()) :: :ok
  def broadcast_hook_executed(board_id, execution, opts \\ []) do
    effects = Keyword.get(opts, :effects, %{})
    result = Keyword.get(opts, :result, :ok)

    payload = %{
      hook_id: execution.hook_id,
      hook_name: execution.hook_name,
      task_id: execution.task_id,
      triggering_column_id: execution.triggering_column_id,
      result: result,
      effects: effects
    }

    Logger.debug(
      "[HookNotifier] Broadcasting hook_executed: #{execution.hook_name} on task #{execution.task_id}"
    )

    Phoenix.PubSub.broadcast(
      Viban.PubSub,
      "kanban_lite:board:#{board_id}",
      {:hook_executed, payload}
    )

    :ok
  end

  @doc """
  Convenience function for broadcasting a play_sound effect.
  """
  @spec broadcast_play_sound(String.t(), %Viban.Kanban.HookExecution{}, String.t()) :: :ok
  def broadcast_play_sound(board_id, execution, sound) do
    broadcast_hook_executed(
      board_id,
      execution,
      effects: %{play_sound: %{sound: sound}}
    )
  end
end
