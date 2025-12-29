/**
 * Sound player utility for hook notifications.
 * Uses HTML5 Audio API for reliable playback.
 */

export type SoundType =
  | "ding"
  | "bell"
  | "chime"
  | "success"
  | "notification"
  | "woof"
  | "bark1"
  | "bark2"
  | "bark3"
  | "bark4"
  | "bark5"
  | "bark6";

const SOUND_FILES: Record<SoundType, string> = {
  ding: "/sounds/ding.wav",
  bell: "/sounds/bell.wav",
  chime: "/sounds/chime.wav",
  success: "/sounds/success.wav",
  notification: "/sounds/notification.wav",
  woof: "/sounds/woof.mp3",
  bark1: "/sounds/bark1.mp3",
  bark2: "/sounds/bark2.mp3",
  bark3: "/sounds/bark3.mp3",
  bark4: "/sounds/bark4.mp3",
  bark5: "/sounds/bark5.mp3",
  bark6: "/sounds/bark6.mp3",
};

// Cache for preloaded audio elements
const audioCache: Map<SoundType, HTMLAudioElement> = new Map();

// Track if audio has been initialized (requires user gesture)
let audioInitialized = false;

/**
 * Initialize the audio system. Call this on a user gesture to enable audio.
 * Returns true if audio is now enabled.
 */
export function initAudio(): boolean {
  if (audioInitialized) return true;

  // Create and load all audio elements
  for (const [type, path] of Object.entries(SOUND_FILES)) {
    const audio = new Audio(path);
    audio.preload = "auto";
    audioCache.set(type as SoundType, audio);
  }

  audioInitialized = true;
  return true;
}

/**
 * Check if audio has been initialized.
 */
export function isAudioInitialized(): boolean {
  return audioInitialized;
}

/**
 * Preload all sound files for faster playback.
 */
export function preloadSounds(): void {
  if (!audioInitialized) {
    initAudio();
  }

  // Trigger load on all cached audio
  for (const audio of audioCache.values()) {
    audio.load();
  }
}

/**
 * Play a notification sound.
 * If audio hasn't been initialized yet, this will silently fail.
 * Returns the audio element so it can be stopped if needed.
 */
export function playSound(type: SoundType = "ding"): HTMLAudioElement | null {
  // Initialize if not already done
  if (!audioInitialized) {
    initAudio();
  }

  let audio = audioCache.get(type);

  if (!audio) {
    // Create on demand if not in cache
    audio = new Audio(SOUND_FILES[type]);
    audioCache.set(type, audio);
  }

  // Clone the audio element to allow overlapping plays
  const clone = audio.cloneNode() as HTMLAudioElement;
  clone.volume = 0.5;
  clone.play().catch((err) => {
    // Silently fail if autoplay is blocked
    console.debug("Sound playback blocked:", err.message);
  });

  return clone;
}

/**
 * Stop a playing audio element.
 */
export function stopSound(audio: HTMLAudioElement | null): void {
  if (audio) {
    audio.pause();
    audio.currentTime = 0;
  }
}

/**
 * Get available sound options for UI dropdowns.
 */
export function getSoundOptions(): { value: SoundType; label: string }[] {
  return [
    { value: "ding", label: "Ding" },
    { value: "bell", label: "Bell" },
    { value: "chime", label: "Chime" },
    { value: "success", label: "Success" },
    { value: "notification", label: "Notification" },
    { value: "woof", label: "Woof" },
    { value: "bark1", label: "Bark 1" },
    { value: "bark2", label: "Bark 2" },
    { value: "bark3", label: "Bark 3" },
    { value: "bark4", label: "Bark 4" },
    { value: "bark5", label: "Bark 5 (Spaniel)" },
    { value: "bark6", label: "Bark 6 (Snarl)" },
  ];
}

/**
 * Get the default sound type.
 */
export function getDefaultSound(): SoundType {
  return "ding";
}
