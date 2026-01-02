import { createCollection } from "@tanstack/db";
import { electricCollectionOptions } from "@tanstack/electric-db-collection";
import type {
  KanbanBoard,
  KanbanColumn,
  KanbanTask,
  KanbanHook,
  KanbanColumnHook,
  KanbanRepository,
  KanbanMessage,
} from "./schema";

const DEFAULT_API_BASE: string | undefined = undefined;

const getApiBase = (): string => {
  if (DEFAULT_API_BASE) return DEFAULT_API_BASE;

  if (typeof window !== "undefined") {
    return window.location.origin;
  }

  throw new Error(
    "No API base URL available: not in browser and no DEFAULT_API_BASE configured",
  );
};

const getUrl = (path: string) => `${getApiBase()}${path}`;

export const syncBoardsCollection = createCollection(
  electricCollectionOptions<KanbanBoard>({
    id: "sync_boards",
    getKey: (item) => item.id,
    shapeOptions: {
      url: getUrl("/api/sync/"),
      params: { query: "sync_boards" },
    },
  }),
);

export const syncColumnsCollection = createCollection(
  electricCollectionOptions<KanbanColumn>({
    id: "sync_columns",
    getKey: (item) => item.id,
    shapeOptions: {
      url: getUrl("/api/sync/"),
      params: { query: "sync_columns" },
    },
  }),
);

export const syncTasksCollection = createCollection(
  electricCollectionOptions<KanbanTask>({
    id: "sync_tasks",
    getKey: (item) => item.id,
    shapeOptions: {
      url: getUrl("/api/sync/"),
      params: { query: "sync_tasks" },
    },
  }),
);

export const syncHooksCollection = createCollection(
  electricCollectionOptions<KanbanHook>({
    id: "sync_hooks",
    getKey: (item) => item.id,
    shapeOptions: {
      url: getUrl("/api/sync/"),
      params: { query: "sync_hooks" },
    },
  }),
);

export const syncColumnHooksCollection = createCollection(
  electricCollectionOptions<KanbanColumnHook>({
    id: "sync_column_hooks",
    getKey: (item) => item.id,
    shapeOptions: {
      url: getUrl("/api/sync/"),
      params: { query: "sync_column_hooks" },
    },
  }),
);

export const syncRepositoriesCollection = createCollection(
  electricCollectionOptions<KanbanRepository>({
    id: "sync_repositories",
    getKey: (item) => item.id,
    shapeOptions: {
      url: getUrl("/api/sync/"),
      params: { query: "sync_repositories" },
    },
  }),
);

export const syncMessagesCollection = createCollection(
  electricCollectionOptions<KanbanMessage>({
    id: "sync_messages",
    getKey: (item) => item.id,
    shapeOptions: {
      url: getUrl("/api/sync/"),
      params: { query: "sync_messages" },
    },
  }),
);
