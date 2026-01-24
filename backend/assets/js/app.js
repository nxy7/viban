// Minimal app.js - Hologram will handle the frontend
// Keep topbar for loading indicators
import topbar from "../vendor/topbar"

topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})

// Sound system for hook notifications
const SOUND_FILES = {
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
}

const audioCache = new Map()
let audioInitialized = false

export function initializeAudio() {
  if (audioInitialized) return true

  for (const [type, path] of Object.entries(SOUND_FILES)) {
    const audio = new Audio(path)
    audio.preload = "auto"
    audioCache.set(type, audio)
  }

  audioInitialized = true
  return true
}

export function playSound(type) {
  if (!audioInitialized) {
    console.log("[Sounds] Audio not initialized, skipping sound:", type)
    return null
  }

  let audio = audioCache.get(type)
  if (!audio) {
    const path = SOUND_FILES[type]
    if (!path) {
      console.warn("[Sounds] Unknown sound type:", type)
      return null
    }
    audio = new Audio(path)
    audioCache.set(type, audio)
  }

  const clone = audio.cloneNode()
  clone.play().catch((err) => {
    console.warn("[Sounds] Failed to play sound:", err)
  })
  return clone
}

// Initialize audio on first user interaction
document.addEventListener('click', () => initializeAudio(), { once: true })
document.addEventListener('keydown', () => initializeAudio(), { once: true })

// Export for use by Hologram
window.Viban = {
  playSound,
  initializeAudio,
  topbar
}
