import { createEffect, createSignal, For, onCleanup, Show } from "solid-js";
import {
  getNotifications,
  type Notification,
  removeNotification,
} from "~/lib/notifications";

const TYPE_STYLES = {
  success: {
    bg: "bg-green-900/95",
    border: "border-green-500/50",
    icon: "text-green-400",
    title: "text-green-300",
  },
  error: {
    bg: "bg-red-900/95",
    border: "border-red-500/50",
    icon: "text-red-400",
    title: "text-red-300",
  },
  warning: {
    bg: "bg-amber-900/95",
    border: "border-amber-500/50",
    icon: "text-amber-400",
    title: "text-amber-300",
  },
  info: {
    bg: "bg-blue-900/95",
    border: "border-blue-500/50",
    icon: "text-blue-400",
    title: "text-blue-300",
  },
};

function NotificationIcon(props: { type: Notification["type"] }) {
  const iconClass = () => `w-5 h-5 ${TYPE_STYLES[props.type].icon}`;

  return (
    <Show
      when={props.type === "success"}
      fallback={
        <Show
          when={props.type === "error"}
          fallback={
            <Show
              when={props.type === "warning"}
              fallback={
                <svg
                  class={iconClass()}
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                  stroke-width="2"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                  />
                </svg>
              }
            >
              <svg
                class={iconClass()}
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                stroke-width="2"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
                />
              </svg>
            </Show>
          }
        >
          <svg
            class={iconClass()}
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
            stroke-width="2"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
            />
          </svg>
        </Show>
      }
    >
      <svg
        class={iconClass()}
        fill="none"
        viewBox="0 0 24 24"
        stroke="currentColor"
        stroke-width="2"
      >
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
        />
      </svg>
    </Show>
  );
}

interface NotificationCardProps {
  notification: Notification;
  index: number;
  totalCount: number;
  isHovered: boolean;
}

function NotificationCard(props: NotificationCardProps) {
  const [isExiting, setIsExiting] = createSignal(false);
  const [progress, setProgress] = createSignal(100);
  const [isPaused, setIsPaused] = createSignal(false);
  const [cardHovered, setCardHovered] = createSignal(false);

  const isFront = () => props.index === props.totalCount - 1;
  const styles = () => TYPE_STYLES[props.notification.type];

  const stackOffset = () => {
    if (props.isHovered) {
      return (props.totalCount - 1 - props.index) * 80;
    }
    return (props.totalCount - 1 - props.index) * 8;
  };

  const stackScale = () => {
    if (props.isHovered) {
      return 1;
    }
    const depth = props.totalCount - 1 - props.index;
    return 1 - depth * 0.03;
  };

  const stackOpacity = () => {
    if (props.isHovered) {
      return 1;
    }
    const depth = props.totalCount - 1 - props.index;
    return 1 - depth * 0.15;
  };

  createEffect(() => {
    if (!isFront() && !props.isHovered) {
      setIsPaused(true);
      return;
    }

    setIsPaused(false);

    const duration = props.notification.duration;
    const startTime = Date.now();
    let animationFrame: number;

    const updateProgress = () => {
      if (isPaused()) {
        animationFrame = requestAnimationFrame(updateProgress);
        return;
      }

      const elapsed = Date.now() - startTime;
      const remaining = Math.max(0, 100 - (elapsed / duration) * 100);
      setProgress(remaining);

      if (remaining > 0) {
        animationFrame = requestAnimationFrame(updateProgress);
      } else {
        handleDismiss();
      }
    };

    animationFrame = requestAnimationFrame(updateProgress);

    onCleanup(() => {
      cancelAnimationFrame(animationFrame);
    });
  });

  const handleDismiss = () => {
    setIsExiting(true);
    setTimeout(() => {
      removeNotification(props.notification.id);
    }, 200);
  };

  return (
    <div
      class={`absolute right-0 w-80 transition-all duration-300 ease-out ${isExiting() ? "opacity-0 translate-x-full" : ""}`}
      style={{
        transform: `translateY(${stackOffset()}px) scale(${stackScale()})`,
        opacity: stackOpacity(),
        "z-index": props.index,
      }}
      onMouseEnter={() => setCardHovered(true)}
      onMouseLeave={() => setCardHovered(false)}
    >
      <div
        class={`relative overflow-hidden rounded-lg border ${styles().bg} ${styles().border} shadow-lg backdrop-blur-sm`}
      >
        <div class="flex items-start gap-3 p-4">
          <div class="flex-shrink-0 mt-0.5">
            <NotificationIcon type={props.notification.type} />
          </div>
          <div class="flex-1 min-w-0">
            <p class={`text-sm font-medium ${styles().title}`}>
              {props.notification.title}
            </p>
            <Show when={props.notification.message}>
              <p class="mt-1 text-sm text-gray-300">
                {props.notification.message}
              </p>
            </Show>
          </div>
          <button
            onClick={handleDismiss}
            class={`flex-shrink-0 p-1 rounded-lg transition-colors ${
              cardHovered() ? "opacity-100 hover:bg-white/10" : "opacity-0"
            }`}
          >
            <svg
              class="w-4 h-4 text-gray-400"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              stroke-width="2"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M6 18L18 6M6 6l12 12"
              />
            </svg>
          </button>
        </div>
        <div
          class="absolute bottom-0 left-0 h-1 bg-white/20 transition-all duration-100"
          style={{ width: `${progress()}%` }}
        />
      </div>
    </div>
  );
}

export default function NotificationContainer() {
  const [isHovered, setIsHovered] = createSignal(false);
  const notifications = getNotifications;

  return (
    <div
      class="fixed top-4 right-4 z-50"
      onMouseEnter={() => setIsHovered(true)}
      onMouseLeave={() => setIsHovered(false)}
    >
      <div class="relative" style={{ height: "auto", "min-height": "1px" }}>
        <For each={notifications()}>
          {(notification, index) => (
            <NotificationCard
              notification={notification}
              index={index()}
              totalCount={notifications().length}
              isHovered={isHovered()}
            />
          )}
        </For>
      </div>
    </div>
  );
}
