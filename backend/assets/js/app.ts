import "../css/app.css"
import "phoenix_html"
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"
import topbar from "../vendor/topbar"
import { createApp, h, shallowRef, defineComponent } from "vue"

// Sound system for hook notifications
const SOUND_FILES: Record<string, string> = {
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

const audioCache = new Map<string, HTMLAudioElement>()
let audioInitialized = false

export function initializeAudio(): boolean {
  if (audioInitialized) return true

  for (const [type, path] of Object.entries(SOUND_FILES)) {
    const audio = new Audio(path)
    audio.preload = "auto"
    audioCache.set(type, audio)
  }

  audioInitialized = true
  return true
}

export function playSound(type: string): HTMLAudioElement | null {
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

  const clone = audio.cloneNode() as HTMLAudioElement
  clone.play().catch((err) => {
    console.warn("[Sounds] Failed to play sound:", err)
  })
  return clone
}

// Initialize audio on first user interaction
document.addEventListener("click", () => initializeAudio(), { once: true })
document.addEventListener("keydown", () => initializeAudio(), { once: true })

// Import Vue components
const components = import.meta.glob("./vue/components/**/*.vue", { eager: true }) as Record<string, { default: any }>

// Create a component registry
const componentRegistry: Record<string, any> = {}
for (const path in components) {
  const name = path.split("/").pop()?.replace(".vue", "") || ""
  componentRegistry[name] = components[path].default
}

// Vue Hook for LiveView integration
const VueHook = {
  mounted(this: any) {
    const hook = this
    const componentName = this.el.dataset.component
    const component = componentRegistry[componentName]

    if (!component) {
      console.error(`[LiveVue] Component not found: ${componentName}`)
      return
    }

    // Parse initial props from data attribute
    const propsStr = this.el.dataset.props || "{}"
    const initialProps = JSON.parse(propsStr)

    // Create reactive props ref
    const props = shallowRef(initialProps)

    // Create wrapper component with event handlers that forward to LiveView
    const WrapperComponent = defineComponent({
      setup() {
        return () => h(component, {
          ...props.value,
          // Forward all events to LiveView
          onMoveTask: (data: any) => hook.pushEvent("move_task", data),
          onCreateTask: (data: any) => hook.pushEvent("show_create_task_modal", data),
          onSelectTask: (data: any) => hook.pushEvent("select_task", data),
          onCloseTaskDetails: () => hook.pushEvent("close_task_details", {}),
          onUpdateTask: (data: any) => hook.pushEvent("update_task", data),
          onDeleteTask: (data: any) => hook.pushEvent("delete_task", data),
          onOpenSettings: (data: any) => hook.pushEvent("open_column_settings", data),
          onCloseSettings: () => hook.pushEvent("close_settings", {}),
          onStartAuth: () => hook.pushEvent("start_auth", {}),
          onShowCreateModal: () => hook.pushEvent("show_create_modal", {}),
          onHideCreateModal: () => hook.pushEvent("hide_create_modal", {}),
          onCreateBoard: (data: any) => hook.pushEvent("create_board", data),
        })
      }
    })

    // Mount Vue app
    const app = createApp(WrapperComponent)
    app.mount(this.el)

    // Store references for updates
    this.vueApp = app
    this.props = props

    // Handle hook events from server
    this.handleEvent("hook_executed", (payload: any) => {
      if (payload.effects?.play_sound) {
        playSound(payload.effects.play_sound.sound)
      }
    })
  },

  updated(this: any) {
    // Update props when LiveView assigns change
    const propsStr = this.el.dataset.props || "{}"
    const newProps = JSON.parse(propsStr)
    this.props.value = newProps
  },

  destroyed(this: any) {
    this.vueApp?.unmount()
  }
}

// Configure topbar
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" })

// Show topbar on live navigation
window.addEventListener("phx:page-loading-start", () => topbar.show(300))
window.addEventListener("phx:page-loading-stop", () => topbar.hide())

// Handle copy to clipboard events from LiveView
window.addEventListener("phx:copy_to_clipboard", (e: Event) => {
  const event = e as CustomEvent
  const text = event.detail?.text
  if (text) {
    navigator.clipboard.writeText(text).then(() => {
      console.log("[Clipboard] Copied:", text)
    }).catch((err) => {
      console.error("[Clipboard] Failed to copy:", err)
    })
  }
})

// LiveSocket setup
const csrfToken = document.querySelector("meta[name='csrf-token']")?.getAttribute("content") || ""
const liveSocket = new LiveSocket("/live", Socket, {
  params: { _csrf_token: csrfToken },
  hooks: {
    VueHook
  }
})

// Connect if there are any LiveViews on the page
liveSocket.connect()

// Expose for debugging
declare global {
  interface Window {
    liveSocket: LiveSocket
    Viban: {
      playSound: typeof playSound
      initializeAudio: typeof initializeAudio
      topbar: typeof topbar
    }
  }
}

window.liveSocket = liveSocket
window.Viban = {
  playSound,
  initializeAudio,
  topbar
}
