defmodule Viban.Kanban.SystemHooks.PlaySoundHook do
  @moduledoc """
  System hook that triggers browser sound playback when a task enters a column.

  When executed, broadcasts a client_action event to the board channel. The frontend
  receives this event and plays the configured sound.

  ## Settings

  The hook_settings on the ColumnHook can specify:
  - `sound`: The sound to play (default: "ding"). Options: "ding", "bell", "chime", "success", "notification"
  """

  @behaviour Viban.Kanban.SystemHooks.Behaviour

  alias VibanWeb.BoardChannel

  require Logger

  @default_sound "ding"

  @impl true
  def id, do: "system:play-sound"

  @impl true
  def name, do: "Play Sound"

  @impl true
  def description do
    "Plays a notification sound in the browser when a task enters this column. " <>
      "Configure the sound in hook settings."
  end

  @impl true
  def execute(_task, _column, opts) do
    board_id = Keyword.get(opts, :board_id)
    hook_settings = Keyword.get(opts, :hook_settings, %{})

    sound = get_sound_from_settings(hook_settings)

    Logger.info("[PlaySoundHook] Broadcasting play-sound to board #{board_id}, sound: #{sound}")

    if board_id do
      BoardChannel.broadcast_client_action(board_id, "play-sound", %{sound: sound})

      Phoenix.PubSub.broadcast(Viban.PubSub, "board:#{board_id}", {:play_sound, sound})
    else
      Logger.warning("[PlaySoundHook] No board_id provided, cannot broadcast")
    end

    :ok
  end

  defp get_sound_from_settings(settings) when is_map(settings) do
    # Support both atom and string keys
    settings[:sound] || settings["sound"] || @default_sound
  end

  defp get_sound_from_settings(_), do: @default_sound
end
