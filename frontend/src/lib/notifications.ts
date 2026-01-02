import { createSignal } from "solid-js";

export type NotificationType = "success" | "error" | "warning" | "info";

export interface Notification {
  id: string;
  type: NotificationType;
  title: string;
  message?: string;
  duration: number;
  createdAt: number;
}

interface NotificationOptions {
  title: string;
  message?: string;
  type?: NotificationType;
  duration?: number;
}

const DEFAULT_DURATION_MS = 7000;

const [notifications, setNotifications] = createSignal<Notification[]>([]);

let notificationIdCounter = 0;

function generateId(): string {
  notificationIdCounter += 1;
  return `notification-${notificationIdCounter}-${Date.now()}`;
}

export function addNotification(options: NotificationOptions): string {
  const id = generateId();
  const notification: Notification = {
    id,
    type: options.type ?? "info",
    title: options.title,
    message: options.message,
    duration: options.duration ?? DEFAULT_DURATION_MS,
    createdAt: Date.now(),
  };

  setNotifications((prev) => [...prev, notification]);
  return id;
}

export function removeNotification(id: string): void {
  setNotifications((prev) => prev.filter((n) => n.id !== id));
}

export function clearAllNotifications(): void {
  setNotifications([]);
}

export function getNotifications() {
  return notifications;
}

export function showSuccess(title: string, message?: string): string {
  return addNotification({ type: "success", title, message });
}

export function showError(title: string, message?: string): string {
  return addNotification({ type: "error", title, message, duration: 10000 });
}

export function showWarning(title: string, message?: string): string {
  return addNotification({ type: "warning", title, message });
}

export function showInfo(title: string, message?: string): string {
  return addNotification({ type: "info", title, message });
}
