/**
 * Shared SVG Icons - Extracted to eliminate DRY violations across components
 *
 * Usage:
 *   import { SettingsIcon, PlusIcon, LoadingSpinner } from "~/components/ui/Icons";
 */

import type { JSX } from "solid-js";

interface IconProps {
  class?: string;
}

/**
 * Settings/Gear icon - used in KanbanBoard header and KanbanColumn settings
 */
export function SettingsIcon(props: IconProps): JSX.Element {
  return (
    <svg
      class={props.class ?? "w-4 h-4"}
      fill="none"
      viewBox="0 0 24 24"
      stroke="currentColor"
    >
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="2"
        d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"
      />
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="2"
        d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"
      />
    </svg>
  );
}

/**
 * Plus icon - used for "Add" buttons throughout the app
 */
export function PlusIcon(props: IconProps): JSX.Element {
  return (
    <svg
      class={props.class ?? "w-4 h-4"}
      fill="none"
      viewBox="0 0 24 24"
      stroke="currentColor"
    >
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="2"
        d="M12 4v16m8-8H4"
      />
    </svg>
  );
}

/**
 * Back arrow icon - used for navigation
 */
export function BackArrowIcon(props: IconProps): JSX.Element {
  return (
    <svg
      class={props.class ?? "w-5 h-5"}
      fill="none"
      stroke="currentColor"
      viewBox="0 0 24 24"
    >
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="2"
        d="M10 19l-7-7m0 0l7-7m-7 7h18"
      />
    </svg>
  );
}

/**
 * Loading spinner - used during async operations
 */
export function LoadingSpinner(props: IconProps): JSX.Element {
  return (
    <svg
      class={`animate-spin ${props.class ?? "h-4 w-4 text-brand-400"}`}
      xmlns="http://www.w3.org/2000/svg"
      fill="none"
      viewBox="0 0 24 24"
    >
      <circle
        class="opacity-25"
        cx="12"
        cy="12"
        r="10"
        stroke="currentColor"
        stroke-width="4"
      />
      <path
        class="opacity-75"
        fill="currentColor"
        d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
      />
    </svg>
  );
}

/**
 * Error/X icon - used for error states
 */
export function ErrorIcon(props: IconProps): JSX.Element {
  return (
    <svg
      class={props.class ?? "h-4 w-4 text-red-400"}
      xmlns="http://www.w3.org/2000/svg"
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
  );
}

/**
 * Clock/Queued icon - used for queued state
 */
export function QueuedIcon(props: IconProps): JSX.Element {
  return (
    <svg
      class={props.class ?? "h-4 w-4 text-yellow-400"}
      xmlns="http://www.w3.org/2000/svg"
      fill="none"
      viewBox="0 0 24 24"
      stroke="currentColor"
      stroke-width="2"
    >
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"
      />
    </svg>
  );
}

/**
 * PR/Git branch icon - used for pull request status
 */
export type PRStatus = "open" | "merged" | "closed" | "draft";

interface PRIconProps extends IconProps {
  status: PRStatus;
}

const PR_STATUS_COLORS: Record<PRStatus, string> = {
  open: "text-green-400",
  merged: "text-purple-400",
  closed: "text-red-400",
  draft: "text-gray-400",
};

export function PRIcon(props: PRIconProps): JSX.Element {
  return (
    <svg
      class={`${props.class ?? "h-3.5 w-3.5"} ${PR_STATUS_COLORS[props.status]}`}
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 14 16"
      fill="currentColor"
    >
      <path d="M0.5 3.25a2.25 2.25 0 1 1 3 2.122v5.256a2.251 2.251 0 1 1-1.5 0V5.372A2.25 2.25 0 0 1 0.5 3.25Zm5.677-.177L8.573.677A.25.25 0 0 1 9 .854V2.5h1A2.5 2.5 0 0 1 12.5 5v5.628a2.251 2.251 0 1 1-1.5 0V5a1 1 0 0 0-1-1h-1v1.646a.25.25 0 0 1-.427.177L6.177 3.427a.25.25 0 0 1 0-.354ZM2.75 2.5a.75.75 0 1 0 0 1.5.75.75 0 0 0 0-1.5Zm0 9.5a.75.75 0 1 0 0 1.5.75.75 0 0 0 0-1.5Zm8.25.75a.75.75 0 1 0 1.5 0 .75.75 0 0 0-1.5 0Z" />
    </svg>
  );
}

/**
 * Folder icon - used for opening folders
 */
export function FolderIcon(props: IconProps): JSX.Element {
  return (
    <svg
      class={props.class ?? "w-4 h-4"}
      fill="none"
      viewBox="0 0 24 24"
      stroke="currentColor"
    >
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="2"
        d="M3 7v10a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-6l-2-2H5a2 2 0 00-2 2z"
      />
    </svg>
  );
}

/**
 * Code editor icon - used for opening in editor
 */
export function CodeEditorIcon(props: IconProps): JSX.Element {
  return (
    <svg
      class={props.class ?? "w-4 h-4"}
      fill="none"
      viewBox="0 0 24 24"
      stroke="currentColor"
    >
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="2"
        d="M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4"
      />
    </svg>
  );
}

/**
 * Lightning/Refine icon - used for AI refinement
 */
export function LightningIcon(props: IconProps): JSX.Element {
  return (
    <svg
      class={props.class ?? "w-4 h-4"}
      fill="none"
      viewBox="0 0 24 24"
      stroke="currentColor"
    >
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="2"
        d="M13 10V3L4 14h7v7l9-11h-7z"
      />
    </svg>
  );
}

/**
 * Duplicate/Copy icon
 */
export function DuplicateIcon(props: IconProps): JSX.Element {
  return (
    <svg
      class={props.class ?? "w-4 h-4"}
      fill="none"
      viewBox="0 0 24 24"
      stroke="currentColor"
    >
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="2"
        d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"
      />
    </svg>
  );
}

/**
 * Trash/Delete icon
 */
export function TrashIcon(props: IconProps): JSX.Element {
  return (
    <svg
      class={props.class ?? "w-4 h-4"}
      fill="none"
      viewBox="0 0 24 24"
      stroke="currentColor"
    >
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="2"
        d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"
      />
    </svg>
  );
}

/**
 * Speaker icon - used for sound/audio settings
 */
export function SpeakerIcon(props: IconProps): JSX.Element {
  return (
    <svg
      class={props.class ?? "w-4 h-4"}
      fill="none"
      viewBox="0 0 24 24"
      stroke="currentColor"
    >
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="2"
        d="M15.536 8.464a5 5 0 010 7.072m2.828-9.9a9 9 0 010 12.728M5.586 15H4a1 1 0 01-1-1v-4a1 1 0 011-1h1.586l4.707-4.707C10.923 3.663 12 4.109 12 5v14c0 .891-1.077 1.337-1.707.707L5.586 15z"
      />
    </svg>
  );
}

/**
 * Play icon - used for executor start button
 */
export function PlayIcon(props: IconProps): JSX.Element {
  return (
    <svg
      class={props.class ?? "w-4 h-4"}
      fill="none"
      viewBox="0 0 24 24"
      stroke="currentColor"
    >
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="2"
        d="M14.752 11.168l-3.197-2.132A1 1 0 0010 9.87v4.263a1 1 0 001.555.832l3.197-2.132a1 1 0 000-1.664z"
      />
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="2"
        d="M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
      />
    </svg>
  );
}

/**
 * Stop icon - used for stopping playback
 */
export function StopIcon(props: IconProps): JSX.Element {
  return (
    <svg
      class={props.class ?? "w-4 h-4"}
      fill="none"
      viewBox="0 0 24 24"
      stroke="currentColor"
    >
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="2"
        d="M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
      />
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="2"
        d="M9 10a1 1 0 011-1h4a1 1 0 011 1v4a1 1 0 01-1 1h-4a1 1 0 01-1-1v-4z"
      />
    </svg>
  );
}

/**
 * Info circle icon - used for system messages
 */
export function InfoIcon(props: IconProps): JSX.Element {
  return (
    <svg
      class={props.class ?? "w-4 h-4"}
      fill="none"
      viewBox="0 0 24 24"
      stroke="currentColor"
    >
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="2"
        d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
      />
    </svg>
  );
}

/**
 * Parent task icon - hierarchical indicator
 */
export function ParentTaskIcon(props: IconProps): JSX.Element {
  return (
    <svg
      class={props.class ?? "w-3 h-3"}
      fill="none"
      viewBox="0 0 24 24"
      stroke="currentColor"
      stroke-width="2"
    >
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M4 6h16M4 12h16m-7 6h7"
      />
    </svg>
  );
}

/**
 * Subtask icon - child task indicator
 */
export function SubtaskIcon(props: IconProps): JSX.Element {
  return (
    <svg
      class={props.class ?? "w-3 h-3"}
      fill="none"
      viewBox="0 0 24 24"
      stroke="currentColor"
      stroke-width="2"
    >
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M13 5l7 7-7 7M5 5l7 7-7 7"
      />
    </svg>
  );
}

/**
 * Checkmark icon - used for in-progress column indicator
 */
export function CheckIcon(props: IconProps): JSX.Element {
  return (
    <svg
      class={props.class ?? "w-3 h-3"}
      fill="currentColor"
      viewBox="0 0 24 24"
    >
      <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z" />
    </svg>
  );
}

/**
 * Close/X icon for modals and panels
 */
export function CloseIcon(props: IconProps): JSX.Element {
  return (
    <svg
      class={props.class ?? "w-4 h-4"}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
    >
      <path d="M18 6L6 18M6 6l12 12" />
    </svg>
  );
}

/**
 * Task created icon - used in activity feed
 */
export function TaskCreatedIcon(props: IconProps): JSX.Element {
  return (
    <svg
      class={props.class ?? "w-4 h-4 text-brand-400"}
      fill="none"
      viewBox="0 0 24 24"
      stroke="currentColor"
    >
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="2"
        d="M12 6v6m0 0v6m0-6h6m-6 0H6"
      />
    </svg>
  );
}

/**
 * Sparkles/AI icon - used for AI-related features (agent hooks, AI generation)
 */
export function SparklesIcon(props: IconProps): JSX.Element {
  return (
    <svg
      class={props.class ?? "w-4 h-4"}
      fill="none"
      viewBox="0 0 24 24"
      stroke="currentColor"
    >
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="2"
        d="M5 3v4M3 5h4M6 17v4m-2-2h4m5-16l2.286 6.857L21 12l-5.714 2.143L13 21l-2.286-6.857L5 12l5.714-2.143L13 3z"
      />
    </svg>
  );
}

/**
 * System/Computer icon - used for system hooks
 */
export function SystemIcon(props: IconProps): JSX.Element {
  return (
    <svg
      class={props.class ?? "w-4 h-4"}
      fill="none"
      viewBox="0 0 24 24"
      stroke="currentColor"
    >
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="2"
        d="M9.75 17L9 20l-1 1h8l-1-1-.75-3M3 13h18M5 17h14a2 2 0 002-2V5a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"
      />
    </svg>
  );
}

/**
 * Terminal icon - used for script hooks
 */
export function TerminalIcon(props: IconProps): JSX.Element {
  return (
    <svg
      class={props.class ?? "w-4 h-4"}
      fill="none"
      viewBox="0 0 24 24"
      stroke="currentColor"
    >
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="2"
        d="M8 9l3 3-3 3m5 0h3M5 20h14a2 2 0 002-2V6a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"
      />
    </svg>
  );
}

/**
 * Edit/Pencil icon - used for edit buttons
 */
export function EditIcon(props: IconProps): JSX.Element {
  return (
    <svg
      class={props.class ?? "w-4 h-4"}
      fill="none"
      viewBox="0 0 24 24"
      stroke="currentColor"
    >
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="2"
        d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"
      />
    </svg>
  );
}

/**
 * Chevron right icon - used for navigation
 */
export function ChevronRightIcon(props: IconProps): JSX.Element {
  return (
    <svg
      class={props.class ?? "w-4 h-4"}
      fill="none"
      viewBox="0 0 24 24"
      stroke="currentColor"
    >
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="2"
        d="M9 5l7 7-7 7"
      />
    </svg>
  );
}

/**
 * Clipboard/List icon - used for subtasks
 */
export function ClipboardListIcon(props: IconProps): JSX.Element {
  return (
    <svg
      class={props.class ?? "w-4 h-4"}
      fill="none"
      viewBox="0 0 24 24"
      stroke="currentColor"
    >
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="2"
        d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"
      />
    </svg>
  );
}

/**
 * Exclamation circle (filled) - used for error states
 */
export function ExclamationCircleIcon(props: IconProps): JSX.Element {
  return (
    <svg
      class={props.class ?? "w-4 h-4"}
      fill="currentColor"
      viewBox="0 0 24 24"
    >
      <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-2h2v2zm0-4h-2V7h2v6z" />
    </svg>
  );
}

/**
 * Check circle (filled) - used for success/executing states
 */
export function CheckCircleFilledIcon(props: IconProps): JSX.Element {
  return (
    <svg
      class={props.class ?? "w-4 h-4"}
      fill="currentColor"
      viewBox="0 0 24 24"
    >
      <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z" />
    </svg>
  );
}

/**
 * Dot icon - small circle indicator
 */
export function DotIcon(props: IconProps): JSX.Element {
  return (
    <svg
      class={props.class ?? "w-4 h-4"}
      fill="currentColor"
      viewBox="0 0 24 24"
    >
      <circle cx="12" cy="12" r="3" />
    </svg>
  );
}

/**
 * Drag handle icon - used for drag-and-drop reordering
 */
export function DragHandleIcon(props: IconProps): JSX.Element {
  return (
    <svg
      class={props.class ?? "w-4 h-4"}
      fill="currentColor"
      viewBox="0 0 24 24"
    >
      <circle cx="9" cy="6" r="1.5" />
      <circle cx="15" cy="6" r="1.5" />
      <circle cx="9" cy="12" r="1.5" />
      <circle cx="15" cy="12" r="1.5" />
      <circle cx="9" cy="18" r="1.5" />
      <circle cx="15" cy="18" r="1.5" />
    </svg>
  );
}

/**
 * Chat bubble icon - used for waiting for user input state
 */
export function ChatBubbleIcon(props: IconProps): JSX.Element {
  return (
    <svg
      class={props.class ?? "w-4 h-4"}
      fill="none"
      viewBox="0 0 24 24"
      stroke="currentColor"
    >
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="2"
        d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"
      />
    </svg>
  );
}

/**
 * External link icon - used for links that open in a new tab
 */
export function ExternalLinkIcon(props: IconProps): JSX.Element {
  return (
    <svg
      class={props.class ?? "w-4 h-4"}
      fill="none"
      viewBox="0 0 24 24"
      stroke="currentColor"
    >
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="2"
        d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"
      />
    </svg>
  );
}

/**
 * Search/magnifying glass icon
 */
export function SearchIcon(props: IconProps): JSX.Element {
  return (
    <svg
      class={props.class ?? "w-4 h-4"}
      fill="none"
      viewBox="0 0 24 24"
      stroke="currentColor"
    >
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="2"
        d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
      />
    </svg>
  );
}

/**
 * Question mark / help icon - for keyboard shortcuts hint
 */
export function HelpIcon(props: IconProps): JSX.Element {
  return (
    <svg
      class={props.class ?? "w-4 h-4"}
      fill="none"
      viewBox="0 0 24 24"
      stroke="currentColor"
    >
      <circle cx="12" cy="12" r="10" stroke-width="2" />
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="2"
        d="M9.09 9a3 3 0 015.83 1c0 2-3 3-3 3"
      />
      <circle cx="12" cy="17" r="0.5" fill="currentColor" stroke="none" />
    </svg>
  );
}

/**
 * Calendar icon - used for scheduled tasks
 */
export function CalendarIcon(props: IconProps): JSX.Element {
  return (
    <svg
      class={props.class ?? "w-4 h-4"}
      fill="none"
      viewBox="0 0 24 24"
      stroke="currentColor"
    >
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="2"
        d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"
      />
    </svg>
  );
}

/**
 * Clock icon - used for time-related features
 */
export function ClockIcon(props: IconProps): JSX.Element {
  return (
    <svg
      class={props.class ?? "w-4 h-4"}
      fill="none"
      viewBox="0 0 24 24"
      stroke="currentColor"
    >
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="2"
        d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"
      />
    </svg>
  );
}

/**
 * Pause icon - used for pausing scheduled tasks
 */
export function PauseIcon(props: IconProps): JSX.Element {
  return (
    <svg
      class={props.class ?? "w-4 h-4"}
      fill="none"
      viewBox="0 0 24 24"
      stroke="currentColor"
    >
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="2"
        d="M10 9v6m4-6v6m7-3a9 9 0 11-18 0 9 9 0 0118 0z"
      />
    </svg>
  );
}
