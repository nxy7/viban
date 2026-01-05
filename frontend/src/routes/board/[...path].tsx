import { useNavigate, useParams } from "@solidjs/router";
import { useLiveQuery } from "@tanstack/solid-db";
import { createEffect, createMemo, on, onCleanup, onMount } from "solid-js";
import KanbanBoard from "~/components/KanbanBoard";
import TaskDetailsPanel from "~/components/TaskDetailsPanel";
import { type Task, tasksCollection, useColumns } from "~/hooks/useKanban";
import { ShortcutProvider } from "~/hooks/useKeyboardShortcuts";
import { SystemProvider } from "~/lib/SystemContext";
import { type ClientActionPayload, socketManager } from "~/lib/socket";
import {
  initAudio,
  playSound,
  preloadSounds,
  type SoundType,
} from "~/lib/sounds";

/** Route segment for card detail views */
const CARD_ROUTE_SEGMENT = "card";

/** Route segment for settings views */
const SETTINGS_ROUTE_SEGMENT = "settings";

/** Minimum path parts required for a card route (boardId/card/cardId) */
const MIN_CARD_ROUTE_PARTS = 3;

/** Minimum path parts required for a settings route (boardId/settings) */
const MIN_SETTINGS_ROUTE_PARTS = 2;

/** Index positions in path array */
const PATH_INDEX = {
  BOARD_ID: 0,
  ROUTE_TYPE: 1,
  CARD_ID: 2,
  SETTINGS_TAB: 2,
} as const;

/** Valid settings tabs */
type SettingsTab =
  | "general"
  | "templates"
  | "hooks"
  | "columns"
  | "scheduled"
  | "system";

/** Parsed route information from URL path */
interface ParsedBoardPath {
  boardId: string;
  cardId: string | null;
  settingsTab: SettingsTab | null;
}

export default function BoardPage() {
  const params = useParams<{ path: string }>();
  const navigate = useNavigate();

  /**
   * Parse the URL path to extract boardId and optional cardId or settings tab.
   * Supports three path formats:
   *   - "boardId" -> board view only
   *   - "boardId/card/cardId" -> board view with card detail panel
   *   - "boardId/settings" or "boardId/settings/tab" -> board view with settings panel
   */
  const parsedPath = createMemo((): ParsedBoardPath => {
    const pathParts = (params.path || "").split("/");
    const boardId = pathParts[PATH_INDEX.BOARD_ID];

    // Check if this is a card route: boardId/card/cardId
    let cardId: string | null = null;
    if (
      pathParts.length >= MIN_CARD_ROUTE_PARTS &&
      pathParts[PATH_INDEX.ROUTE_TYPE] === CARD_ROUTE_SEGMENT
    ) {
      cardId = pathParts[PATH_INDEX.CARD_ID];
    }

    // Check if this is a settings route: boardId/settings or boardId/settings/tab
    let settingsTab: SettingsTab | null = null;
    if (
      pathParts.length >= MIN_SETTINGS_ROUTE_PARTS &&
      pathParts[PATH_INDEX.ROUTE_TYPE] === SETTINGS_ROUTE_SEGMENT
    ) {
      // Default to "general" if no specific tab is provided
      const tabParam = pathParts[PATH_INDEX.SETTINGS_TAB];
      if (
        tabParam === "hooks" ||
        tabParam === "columns" ||
        tabParam === "scheduled" ||
        tabParam === "system"
      ) {
        settingsTab = tabParam;
      } else {
        settingsTab = "general";
      }
    }

    return { boardId, cardId, settingsTab };
  });

  const boardId = () => parsedPath().boardId;
  const cardId = () => parsedPath().cardId;
  const settingsTab = () => parsedPath().settingsTab;

  // Get columns to find the column name for a task
  const { columns } = useColumns(boardId);

  /**
   * Query all tasks to find the selected one.
   * Selects all Task fields needed by TaskDetailsPanel.
   */
  const tasksQuery = useLiveQuery((q) =>
    q
      .from({ tasks: tasksCollection })
      .orderBy(({ tasks }) => tasks.position, "asc")
      .select(({ tasks }) => ({
        id: tasks.id,
        column_id: tasks.column_id,
        title: tasks.title,
        description: tasks.description,
        description_images: tasks.description_images,
        position: tasks.position,
        worktree_path: tasks.worktree_path,
        worktree_branch: tasks.worktree_branch,
        custom_branch_name: tasks.custom_branch_name,
        agent_status: tasks.agent_status,
        agent_status_message: tasks.agent_status_message,
        in_progress: tasks.in_progress,
        error_message: tasks.error_message,
        queued_at: tasks.queued_at,
        queue_priority: tasks.queue_priority,
        pr_url: tasks.pr_url,
        pr_number: tasks.pr_number,
        pr_status: tasks.pr_status,
        parent_task_id: tasks.parent_task_id,
        is_parent: tasks.is_parent,
        subtask_position: tasks.subtask_position,
        subtask_generation_status: tasks.subtask_generation_status,
        inserted_at: tasks.inserted_at,
        updated_at: tasks.updated_at,
      })),
  );

  /**
   * All tasks from the query, defaulting to empty array.
   * The query select explicitly defines the Task shape, so the data matches Task[].
   */
  const allTasks = (): Task[] => {
    const data = tasksQuery.data;
    if (!Array.isArray(data)) return [];
    return data as Task[];
  };

  // Derive selected task and column from URL
  const selectedTask = createMemo(() => {
    const id = cardId();
    if (!id) return null;
    return allTasks().find((t) => t.id === id) || null;
  });

  const selectedTaskColumnName = createMemo(() => {
    const task = selectedTask();
    if (!task) return "";
    const column = columns().find((c) => c.id === task.column_id);
    return column?.name || "";
  });

  // Navigation handlers
  const openCardDetails = (task: Task) => {
    navigate(`/board/${boardId()}/card/${task.id}`);
  };

  const closeCardDetails = () => {
    navigate(`/board/${boardId()}`);
  };

  const openSettings = (tab: SettingsTab = "general") => {
    navigate(`/board/${boardId()}/settings/${tab}`);
  };

  const closeSettings = () => {
    navigate(`/board/${boardId()}`);
  };

  const changeSettingsTab = (tab: SettingsTab) => {
    navigate(`/board/${boardId()}/settings/${tab}`, { replace: true });
  };

  // Handle card not found - redirect to board
  createEffect(() => {
    // Only check after data is loaded and if we have a cardId in the URL
    if (
      cardId() &&
      tasksQuery.data &&
      tasksQuery.data.length > 0 &&
      !selectedTask()
    ) {
      // Task doesn't exist, navigate back to board
      navigate(`/board/${boardId()}`, { replace: true });
    }
  });

  // Panel is open when cardId is in URL
  const isPanelOpen = () => !!cardId();

  // Initialize audio system on first user interaction (browser autoplay policy)
  onMount(() => {
    const handleFirstInteraction = () => {
      initAudio();
      preloadSounds();
      document.removeEventListener("click", handleFirstInteraction);
      document.removeEventListener("keydown", handleFirstInteraction);
    };
    document.addEventListener("click", handleFirstInteraction);
    document.addEventListener("keydown", handleFirstInteraction);

    onCleanup(() => {
      document.removeEventListener("click", handleFirstInteraction);
      document.removeEventListener("keydown", handleFirstInteraction);
    });
  });

  // Subscribe to board channel for client actions (e.g., play-sound from hooks)
  createEffect(
    on(boardId, (currentBoardId, prevBoardId) => {
      // Leave previous board channel
      if (prevBoardId) {
        socketManager.leaveBoardChannel(prevBoardId);
      }

      // Join new board channel
      if (currentBoardId) {
        socketManager
          .joinBoardChannel(currentBoardId, {
            onClientAction: (data: ClientActionPayload) => {
              console.log("[BoardPage] Received client_action:", data);
              handleClientAction(data);
            },
          })
          .catch((err) => {
            console.error("[BoardPage] Failed to join board channel:", err);
          });
      }

      // Cleanup on unmount
      onCleanup(() => {
        if (currentBoardId) {
          socketManager.leaveBoardChannel(currentBoardId);
        }
      });
    }),
  );

  // Track last played sound to debounce duplicates
  let lastSoundTime = 0;
  const SOUND_DEBOUNCE_MS = 500;

  /** Handle client actions from the board channel */
  function handleClientAction(action: ClientActionPayload) {
    switch (action.type) {
      case "play-sound": {
        const now = Date.now();
        // Debounce rapid duplicate sounds
        if (now - lastSoundTime < SOUND_DEBOUNCE_MS) {
          console.log("[BoardPage] Debouncing duplicate sound");
          return;
        }
        lastSoundTime = now;

        const soundType = (action.sound || "ding") as SoundType;
        console.log("[BoardPage] Playing sound:", soundType);
        playSound(soundType);
        break;
      }
      default:
        console.warn("[BoardPage] Unknown client action type:", action);
    }
  }

  return (
    <SystemProvider>
      <ShortcutProvider>
        <KanbanBoard
          boardId={boardId()}
          onTaskClick={openCardDetails}
          settingsTab={settingsTab()}
          onOpenSettings={openSettings}
          onCloseSettings={closeSettings}
          onChangeSettingsTab={changeSettingsTab}
          selectedTaskId={cardId()}
          onNavigateToTask={openCardDetails}
        />

        <TaskDetailsPanel
          isOpen={isPanelOpen()}
          onClose={closeCardDetails}
          task={selectedTask()}
          columnName={selectedTaskColumnName()}
        />
      </ShortcutProvider>
    </SystemProvider>
  );
}
