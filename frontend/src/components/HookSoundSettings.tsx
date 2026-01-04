import { type Accessor, createSignal, For, Show } from "solid-js";
import { Button, Select } from "~/components/design-system";
import {
  getSoundOptions,
  playSound,
  type SoundType,
  stopSound,
} from "~/lib/sounds";
import { PlayIcon, StopIcon } from "./ui/Icons";

interface HookSoundSettingsProps {
  currentSound: Accessor<SoundType>;
  onChange: (sound: SoundType) => void;
}

/**
 * Sound selection component for the Play Sound hook.
 * Shows a dropdown of available sounds with a preview/stop button.
 */
export default function HookSoundSettings(props: HookSoundSettingsProps) {
  const options = getSoundOptions();
  const [isPlaying, setIsPlaying] = createSignal(false);
  const [currentAudio, setCurrentAudio] = createSignal<HTMLAudioElement | null>(
    null,
  );

  const handlePreview = () => {
    if (isPlaying()) {
      stopSound(currentAudio());
      setCurrentAudio(null);
      setIsPlaying(false);
    } else {
      const audio = playSound(props.currentSound());
      if (audio) {
        setCurrentAudio(audio);
        setIsPlaying(true);

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
        <Select
          value={props.currentSound()}
          onChange={(e) => {
            if (isPlaying()) {
              stopSound(currentAudio());
              setCurrentAudio(null);
              setIsPlaying(false);
            }
            props.onChange(e.currentTarget.value as SoundType);
          }}
          variant="dark"
          selectSize="sm"
          fullWidth
        >
          <For each={options}>
            {(opt) => <option value={opt.value}>{opt.label}</option>}
          </For>
        </Select>
        <Button
          type="button"
          onClick={handlePreview}
          variant={isPlaying() ? "danger" : "secondary"}
          buttonSize="sm"
          title={isPlaying() ? "Stop" : "Preview sound"}
        >
          <Show when={isPlaying()} fallback={<PlayIcon class="w-3 h-3" />}>
            <StopIcon class="w-3 h-3" />
          </Show>
        </Button>
      </div>
    </div>
  );
}
