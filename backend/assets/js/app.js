// Phoenix and LiveView setup
import "phoenix_html"
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"
import Sortable from "../vendor/sortablejs"

// ============================================================================
// LiveView Hooks
// ============================================================================

const Hooks = {}

// ============================================================================
// Keyboard Shortcuts Hook
// ============================================================================

Hooks.KeyboardShortcuts = {
  mounted() {
    this.handleKeydown = (e) => {
      const target = e.target
      const tagName = target.tagName.toLowerCase()
      const isEditable = tagName === 'input' || tagName === 'textarea' || tagName === 'select' || target.isContentEditable

      if (e.key === 'Escape') {
        this.pushEvent("shortcut_escape", {})
        return
      }

      if (isEditable) return

      if (e.shiftKey && e.key === '?') {
        e.preventDefault()
        this.pushEvent("shortcut_help", {})
        return
      }

      if (e.key === 'n' && !e.ctrlKey && !e.metaKey) {
        e.preventDefault()
        this.pushEvent("shortcut_new_task", {})
        return
      }

      if (e.key === '/') {
        e.preventDefault()
        this.pushEvent("shortcut_focus_search", {})
        return
      }

      if (e.key === ',') {
        e.preventDefault()
        this.pushEvent("show_settings", {})
        return
      }

      if (e.key === 'ArrowLeft') {
        e.preventDefault()
        this.pushEvent("shortcut_prev_task", {})
        return
      }

      if (e.key === 'ArrowRight') {
        e.preventDefault()
        this.pushEvent("shortcut_next_task", {})
        return
      }

      if (e.key === 'Backspace') {
        e.preventDefault()
        this.pushEvent("shortcut_delete_task", {})
        return
      }
    }

    window.addEventListener('keydown', this.handleKeydown)
  },

  destroyed() {
    window.removeEventListener('keydown', this.handleKeydown)
  }
}

// ============================================================================
// Focus Search Hook
// ============================================================================

Hooks.FocusSearch = {
  mounted() {
    this.handleEvent("focus_search", () => {
      this.el.focus()
      this.el.select()
    })
  }
}

Hooks.SortableTasks = {
  mounted() {
    const columnId = this.el.dataset.columnId

    this.sortable = new Sortable(this.el, {
      group: "tasks",
      animation: 150,
      ghostClass: "opacity-50",
      chosenClass: "sortable-chosen",
      dragClass: "shadow-xl",
      handle: "[data-task-id]",
      draggable: "[data-task-id]",

      onEnd: (evt) => {
        const taskId = evt.item.dataset.taskId
        const newColumnId = evt.to.dataset.columnId
        const newIndex = evt.newIndex

        // Find the task IDs in the new column for position calculation
        const tasksInColumn = Array.from(evt.to.querySelectorAll("[data-task-id]"))
        const beforeTaskId = newIndex < tasksInColumn.length - 1
          ? tasksInColumn[newIndex + 1]?.dataset.taskId
          : null
        const afterTaskId = newIndex > 0
          ? tasksInColumn[newIndex - 1]?.dataset.taskId
          : null

        // Only trigger if actually moved
        if (evt.from !== evt.to || evt.oldIndex !== evt.newIndex) {
          this.pushEvent("move_task", {
            task_id: taskId,
            column_id: newColumnId,
            before_task_id: beforeTaskId || "",
            after_task_id: afterTaskId || ""
          })
        }
      }
    })
  },

  updated() {
    // Sortable handles updates automatically
  },

  destroyed() {
    if (this.sortable) {
      this.sortable.destroy()
    }
  }
}

// ============================================================================
// Task Panel Shortcuts Hook
// ============================================================================

Hooks.TaskPanelShortcuts = {
  mounted() {
    this.handleKeydown = (e) => {
      const target = e.target
      const tagName = target.tagName.toLowerCase()
      const isEditable = tagName === 'input' || tagName === 'textarea' || tagName === 'select' || target.isContentEditable

      if (isEditable) return

      if (e.key === 'f' && !e.ctrlKey && !e.metaKey) {
        e.preventDefault()
        this.pushEvent("toggle_fullscreen", {})
        return
      }

      if (e.key === 'h' && e.ctrlKey) {
        e.preventDefault()
        this.pushEvent("toggle_details", {})
        return
      }

      if (e.key === 'd' && e.ctrlKey) {
        e.preventDefault()
        this.pushEvent("duplicate_task", { task_id: this.el.dataset.taskId })
        return
      }

      if (e.key === 'p' && e.ctrlKey) {
        e.preventDefault()
        this.pushEvent("show_pr_modal", {})
        return
      }
    }

    window.addEventListener('keydown', this.handleKeydown)

    this.handleEvent("submit_chat", () => {
      const form = this.el.querySelector('form[phx-submit="send_chat_message"]')
      if (form) {
        form.requestSubmit()
      }
    })
  },

  destroyed() {
    window.removeEventListener('keydown', this.handleKeydown)
  }
}

// ============================================================================
// Sound System Hook
// ============================================================================

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
let lastPlayedSound = null
let lastPlayedTime = 0

function initializeAudio() {
  if (audioInitialized) return true

  for (const [type, path] of Object.entries(SOUND_FILES)) {
    const audio = new Audio(path)
    audio.preload = "auto"
    audioCache.set(type, audio)
  }

  audioInitialized = true
  return true
}

function playSound(type) {
  if (!audioInitialized) {
    console.log("[Sounds] Audio not initialized, skipping sound:", type)
    return null
  }

  const now = Date.now()
  if (type === lastPlayedSound && now - lastPlayedTime < 100) {
    console.log("[Sounds] Debouncing duplicate sound:", type)
    return null
  }

  lastPlayedSound = type
  lastPlayedTime = now

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

Hooks.SoundSystem = {
  mounted() {
    this.initOnInteraction = (e) => {
      initializeAudio()
      document.removeEventListener('click', this.initOnInteraction)
      document.removeEventListener('keydown', this.initOnInteraction)
    }

    document.addEventListener('click', this.initOnInteraction)
    document.addEventListener('keydown', this.initOnInteraction)

    this.handleEvent("play_sound", ({ sound }) => {
      console.log("[Sounds] Received play_sound event:", sound)
      playSound(sound || "ding")
    })
  },

  destroyed() {
    document.removeEventListener('click', this.initOnInteraction)
    document.removeEventListener('keydown', this.initOnInteraction)
  }
}

// ============================================================================
// Native Dialog Hook
// ============================================================================

Hooks.Dialog = {
  mounted() {
    const dialog = this.el
    this.isClosing = false
    this.justOpened = false

    this.openDialog = () => {
      if (dialog.open) return
      this.justOpened = true
      dialog.showModal()
      requestAnimationFrame(() => {
        this.justOpened = false
      })
    }

    if (dialog.dataset.show === "true") {
      this.openDialog()
    }

    dialog.addEventListener("phx:show-modal", () => {
      this.openDialog()
    })

    dialog.addEventListener("phx:hide-modal", () => {
      this.isClosing = true
      dialog.close()
    })

    dialog.addEventListener("close", () => {
      if (!this.isClosing) {
        const cancelAttr = dialog.dataset.cancel
        if (cancelAttr) {
          window.liveSocket.execJS(dialog, cancelAttr)
        }
      }
      this.isClosing = false
    })

    dialog.addEventListener("click", (e) => {
      if (this.justOpened) return
      if (e.target === dialog) {
        dialog.close()
      }
    })
  },

  updated() {
    const dialog = this.el
    if (dialog.dataset.show === "true" && !dialog.open) {
      this.openDialog()
    }
  }
}

// ============================================================================
// Copy To Clipboard Hook
// ============================================================================

Hooks.CopyToClipboard = {
  mounted() {
    this.el.addEventListener("click", () => {
      const text = this.el.dataset.copyText
      if (text) {
        navigator.clipboard.writeText(text).then(() => {
          const hint = this.el.querySelector('[data-copy-hint]')
          if (hint) {
            const originalText = hint.textContent
            hint.textContent = 'Copied!'
            hint.classList.add('text-green-400')
            setTimeout(() => {
              hint.textContent = originalText
              hint.classList.remove('text-green-400')
            }, 2000)
          }
        })
      }
    })
  }
}

// ============================================================================
// Scroll To Bottom Hook
// ============================================================================

Hooks.ScrollToBottom = {
  mounted() {
    this.scrollToBottom()
    this.observer = new MutationObserver(() => {
      this.scrollToBottom()
    })
    this.observer.observe(this.el, { childList: true, subtree: true })
  },

  updated() {
    this.scrollToBottom()
  },

  scrollToBottom() {
    this.el.scrollTop = this.el.scrollHeight
  },

  destroyed() {
    if (this.observer) {
      this.observer.disconnect()
    }
  }
}

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: Hooks
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket
