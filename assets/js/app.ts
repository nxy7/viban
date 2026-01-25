import "../css/app.css";
import "phoenix_html";
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import topbar from "../vendor/topbar";
import { createApp, h, shallowRef, defineComponent } from "vue";

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
};

const audioCache = new Map<string, HTMLAudioElement>();
let audioInitialized = false;

export function initializeAudio(): boolean {
  if (audioInitialized) return true;

  for (const [type, path] of Object.entries(SOUND_FILES)) {
    const audio = new Audio(path);
    audio.preload = "auto";
    audioCache.set(type, audio);
  }

  audioInitialized = true;
  return true;
}

export function playSound(type: string): HTMLAudioElement | null {
  if (!audioInitialized) {
    console.log("[Sounds] Audio not initialized, skipping sound:", type);
    return null;
  }

  let audio = audioCache.get(type);
  if (!audio) {
    const path = SOUND_FILES[type];
    if (!path) {
      console.warn("[Sounds] Unknown sound type:", type);
      return null;
    }
    audio = new Audio(path);
    audioCache.set(type, audio);
  }

  const clone = audio.cloneNode() as HTMLAudioElement;
  clone.play().catch((err) => {
    console.warn("[Sounds] Failed to play sound:", err);
  });
  return clone;
}

// Initialize audio on first user interaction
document.addEventListener("click", () => initializeAudio(), { once: true });
document.addEventListener("keydown", () => initializeAudio(), { once: true });

// Import Vue components
const components = import.meta.glob("./vue/components/**/*.vue", {
  eager: true,
}) as Record<string, { default: any }>;

// Create a component registry
const componentRegistry: Record<string, any> = {};
for (const path in components) {
  const name = path.split("/").pop()?.replace(".vue", "") || "";
  componentRegistry[name] = components[path].default;
}

// Vue Hook for LiveView integration
const VueHook = {
  mounted(this: any) {
    const hook = this;
    const componentName = this.el.dataset.component;
    const component = componentRegistry[componentName];

    if (!component) {
      console.error(`[LiveVue] Component not found: ${componentName}`);
      return;
    }

    // Parse initial props from data attribute
    const propsStr = this.el.dataset.props || "{}";
    const initialProps = JSON.parse(propsStr);

    // Create reactive props ref
    const props = shallowRef(initialProps);

    // Create wrapper component with event handlers that forward to LiveView
    const WrapperComponent = defineComponent({
      setup() {
        return () =>
          h(component, {
            ...props.value,
            // Forward all events to LiveView
            onMoveTask: (data: any) => hook.pushEvent("move_task", data),
            onCreateTask: (data: any) =>
              hook.pushEvent("show_create_task_modal", data),
            onSelectTask: (data: any) => hook.pushEvent("select_task", data),
            onCloseTaskDetails: () => hook.pushEvent("close_task_details", {}),
            onUpdateTask: (data: any) => hook.pushEvent("update_task", data),
            onDeleteTask: (data: any) => hook.pushEvent("delete_task", data),
            onOpenSettings: (data: any) =>
              hook.pushEvent("open_column_settings", data),
            onCloseSettings: () => hook.pushEvent("close_settings", {}),
            onStartAuth: () => hook.pushEvent("start_auth", {}),
            onShowCreateModal: () => hook.pushEvent("show_create_modal", {}),
            onHideCreateModal: () => hook.pushEvent("hide_create_modal", {}),
            onCreateBoard: (data: any) => hook.pushEvent("create_board", data),
            // TaskDetailsPanel events
            onClose: () => hook.pushEvent("close_task_details", {}),
            onToggleFullscreen: () => hook.pushEvent("toggle_fullscreen", {}),
            onToggleHideDetails: () =>
              hook.pushEvent("toggle_hide_details", {}),
            onOpenFolder: (data: any) =>
              hook.pushEvent("open_folder", { "task-id": data.taskId }),
            onOpenInEditor: (data: any) =>
              hook.pushEvent("open_in_editor", { "task-id": data.taskId }),
            onShowCreatePrModal: (data: any) =>
              hook.pushEvent("show_create_pr_modal", {
                "task-id": data.taskId,
              }),
            onSendMessage: (data: any) =>
              hook.pushEvent("send_message", {
                task_id: data.taskId,
                message: data.message,
              }),
            onClearError: (data: any) =>
              hook.pushEvent("clear_error", { taskId: data.taskId }),
            onCreateWorktree: (data: any) =>
              hook.pushEvent("create_worktree", { task_id: data.taskId }),
          });
      },
    });

    // Mount Vue app
    const app = createApp(WrapperComponent);
    app.mount(this.el);

    // Store references for updates
    this.vueApp = app;
    this.props = props;

    // Handle hook events from server
    this.handleEvent("hook_executed", (payload: any) => {
      if (payload.effects?.play_sound) {
        playSound(payload.effects.play_sound.sound);
      }
    });
  },

  updated(this: any) {
    // Update props when LiveView assigns change
    const propsStr = this.el.dataset.props || "{}";
    const newProps = JSON.parse(propsStr);
    this.props.value = newProps;
  },

  destroyed(this: any) {
    this.vueApp?.unmount();
  },
};

// Configure topbar
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" });

// Show topbar on live navigation
window.addEventListener("phx:page-loading-start", () => topbar.show(300));
window.addEventListener("phx:page-loading-stop", () => topbar.hide());

// Handle copy to clipboard events from LiveView
window.addEventListener("phx:copy_to_clipboard", (e: Event) => {
  const event = e as CustomEvent;
  const text = event.detail?.text;
  if (text) {
    navigator.clipboard
      .writeText(text)
      .then(() => {
        console.log("[Clipboard] Copied:", text);
      })
      .catch((err) => {
        console.error("[Clipboard] Failed to copy:", err);
      });
  }
});

// Handle set_board_name event from LiveView
window.addEventListener("phx:set_board_name", (e: Event) => {
  const event = e as CustomEvent;
  const name = event.detail?.name;
  if (name) {
    const input = document.getElementById("board_name") as HTMLInputElement;
    if (input && !input.value) {
      input.value = name;
    }
  }
});

// LiveSocket setup
const csrfToken =
  document.querySelector("meta[name='csrf-token']")?.getAttribute("content") ||
  "";
const liveSocket = new LiveSocket("/live", Socket, {
  params: { _csrf_token: csrfToken },
  hooks: {
    VueHook,
  },
});

// Connect if there are any LiveViews on the page
liveSocket.connect();

// Keyboard shortcuts handler
document.addEventListener("keydown", (e: KeyboardEvent) => {
  const target = e.target as HTMLElement;
  const tagName = target.tagName.toLowerCase();
  const isEditable =
    tagName === "input" || tagName === "textarea" || target.isContentEditable;

  // Allow Escape to work even in editable elements
  if (e.key === "Escape") {
    const escapeBtn = document.querySelector(
      "[data-keyboard-escape]",
    ) as HTMLButtonElement;
    if (escapeBtn) {
      escapeBtn.click();
      return;
    }
  }

  // Don't handle other shortcuts when typing in inputs
  if (isEditable) return;

  // ? or Shift+/ - Show keyboard shortcuts
  if (e.key === "?" || (e.key === "/" && e.shiftKey)) {
    e.preventDefault();
    const helpBtn = document.querySelector(
      "[data-keyboard-help]",
    ) as HTMLButtonElement;
    if (helpBtn) helpBtn.click();
    return;
  }

  // / - Focus search
  if (e.key === "/") {
    e.preventDefault();
    const searchInput = document.querySelector(
      "[data-keyboard-search]",
    ) as HTMLInputElement;
    if (searchInput) searchInput.focus();
    return;
  }

  // , - Open settings
  if (e.key === ",") {
    e.preventDefault();
    const settingsBtn = document.querySelector(
      "[data-keyboard-settings]",
    ) as HTMLButtonElement;
    if (settingsBtn) settingsBtn.click();
    return;
  }

  // n - New task
  if (e.key === "n") {
    e.preventDefault();
    const newTaskBtn = document.querySelector(
      "[data-keyboard-new-task]",
    ) as HTMLButtonElement;
    if (newTaskBtn) newTaskBtn.click();
    return;
  }
});

// Expose for debugging
declare global {
  interface Window {
    liveSocket: LiveSocket;
    Viban: {
      playSound: typeof playSound;
      initializeAudio: typeof initializeAudio;
      topbar: typeof topbar;
    };
  }
}

window.liveSocket = liveSocket;
window.Viban = {
  playSound,
  initializeAudio,
  topbar,
};
