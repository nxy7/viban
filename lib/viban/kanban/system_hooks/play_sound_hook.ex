defmodule Viban.Kanban.SystemHooks.PlaySoundHook do
  @moduledoc """
  System hook that triggers browser sound playback when a task enters a column.

  When executed, broadcasts a hook_executed event with play_sound effect to all
  clients via Phoenix PubSub. The frontend receives this event and plays the
  configured sound.

  ## Settings

  The hook_settings on the ColumnHook can specify:
  - `sound`: The sound to play (default: "ding"). Options: "ding", "bell", "chime", "success", "notification"
  """

  @behaviour Viban.Kanban.SystemHooks.Behaviour

  alias Viban.Kanban.TaskActivityNotifier

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
  def execute(task, _column, opts) do
    hook_settings = Keyword.get(opts, :hook_settings, %{})
    execution = Keyword.get(opts, :execution)

    sound = get_sound_from_settings(hook_settings)

    Logger.info("[PlaySoundHook] Broadcasting play-sound effect, sound: #{sound}")

    if execution do
      TaskActivityNotifier.broadcast_hook_effect(task.id, execution, %{
        play_sound: %{sound: sound}
      })
    else
      Logger.warning("[PlaySoundHook] Missing execution, cannot broadcast effect")
    end

    :ok
  end

  defp get_sound_from_settings(settings) when is_map(settings) do
    # Support both atom and string keys
    settings[:sound] || settings["sound"] || @default_sound
  end

  defp get_sound_from_settings(_), do: @default_sound
end
