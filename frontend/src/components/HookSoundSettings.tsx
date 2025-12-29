import { createSignal, For, Show } from "solid-js";
import {
  getSoundOptions,
  playSound,
  stopSound,
  type SoundType,
} from "~/lib/sounds";
import { PlayIcon, StopIcon } from "./ui/Icons";

interface HookSoundSettingsProps {
  currentSound: SoundType;
  onChange: (sound: SoundType) => void;
}

/**
 * Sound selection component for the Play Sound hook.
 * Shows a dropdown of available sounds with a preview/stop button.
 */
export default function HookSoundSettings(props: HookSoundSettingsProps) {
  const options = getSoundOptions();
  const [isPlaying, setIsPlaying] = createSignal(false);
  const [currentAudio, setCurrentAudio] =
    createSignal<HTMLAudioElement | null>(null);

  const handlePreview = () => {
    if (isPlaying()) {
      // Stop currently playing sound
      stopSound(currentAudio());
      setCurrentAudio(null);
      setIsPlaying(false);
    } else {
      // Play new sound
      const audio = playSound(props.currentSound);
      if (audio) {
        setCurrentAudio(audio);
        setIsPlaying(true);

        // Reset state when sound ends
        audio.onended = () => {
          setIsPlaying(false);
          setCurrentAudio(null);
        };
      }
    }
  };

  return (
    <div class="mt-2 pt-2 border-t border-gray-700/50">
      <label class="block text-xs text-gray-400 mb-1.5">
        Notification Sound
      </label>
      <div class="flex gap-2">
        <select
          value={props.currentSound}
          onChange={(e) => {
            // Stop any playing sound when changing selection
            if (isPlaying()) {
              stopSound(currentAudio());
              setCurrentAudio(null);
              setIsPlaying(false);
            }
            props.onChange(e.currentTarget.value as SoundType);
          }}
          class="flex-1 px-2 py-1.5 bg-gray-900 border border-gray-700 rounded text-white text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
        >
          <For each={options}>
            {(opt) => <option value={opt.value}>{opt.label}</option>}
          </For>
        </select>
        <button
          type="button"
          onClick={handlePreview}
          class={`px-2.5 py-1.5 rounded text-sm transition-colors flex items-center gap-1 ${
            isPlaying()
              ? "bg-red-600 hover:bg-red-700 text-white"
              : "bg-gray-700 hover:bg-gray-600 text-gray-300"
          }`}
          title={isPlaying() ? "Stop" : "Preview sound"}
        >
          <Show when={isPlaying()} fallback={<PlayIcon class="w-3 h-3" />}>
            <StopIcon class="w-3 h-3" />
          </Show>
        </button>
      </div>
    </div>
  );
}
