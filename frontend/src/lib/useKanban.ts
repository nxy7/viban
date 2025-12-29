/**
 * useKanban - Core Kanban data layer with Electric SQL real-time sync.
 *
 * This module provides:
 * - Type definitions for all Kanban entities
 * - Electric SQL collections for real-time sync
 * - React hooks for querying data
 * - RPC mutations for data updates
 */

import { createCollection, eq, inArray } from "@tanstack/db";
import { electricCollectionOptions } from "@tanstack/electric-db-collection";
import { useLiveQuery } from "@tanstack/solid-db";

// ============================================================================
// Configuration Constants
// ============================================================================

/** Default API base URL for SSR/server context */
const DEFAULT_API_BASE = "http://localhost:8000";

/**
 * Returns the API base URL.
 * Uses window.location.origin in browser (through Caddy proxy for HTTP/2 support).
 */
const getApiBase = (): string => {
  if (typeof window !== "undefined") {
    return window.location.origin;
  }
  return DEFAULT_API_BASE;
};

// ============================================================================
// Type Guards for Runtime Validation
// ============================================================================

/**
 * Type guard to check if a value is a non-null object.
 * Used as a foundation for more specific type guards.
 */
function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

/**
 * Type guard to validate Task objects from API responses.
 * Uses minimal checks to avoid filtering out valid data from Electric sync.
 */
export function isTask(data: unknown): data is Task {
  if (!isObject(data)) return false;
  // Only check for required string fields - position may be string from DB
  return (
    typeof data.id === "string" &&
    typeof data.column_id === "string" &&
    typeof data.title === "string"
  );
}

/**
 * Type guard to validate Board objects from API responses.
 */
export function isBoard(data: unknown): data is Board {
  if (!isObject(data)) return false;
  return (
    typeof data.id === "string" &&
    typeof data.name === "string" &&
    typeof data.inserted_at === "string"
  );
}

/**
 * Type guard to validate Column objects from API responses.
 */
export function isColumn(data: unknown): data is Column {
  if (!isObject(data)) return false;
  return (
    typeof data.id === "string" &&
    typeof data.board_id === "string" &&
    typeof data.name === "string" &&
    typeof data.position === "number"
  );
}

/**
 * Safely validates and returns an array of items using a type guard.
 * Returns an empty array if validation fails.
 */
export function validateArray<T>(
  data: unknown,
  guard: (item: unknown) => item is T,
): T[] {
  if (!Array.isArray(data)) return [];
  return data.filter(guard);
}

// ============================================================================
// Type Definitions
// ============================================================================

// Types for Kanban entities
export interface Board {
  id: string;
  name: string;
  description: string | null;
  inserted_at: string;
  updated_at: string;
}

export interface ColumnSettings {
  max_concurrent_tasks?: number | null;
  description?: string | null;
  auto_move_on_complete?: boolean;
  require_confirmation?: boolean;
  hooks_enabled?: boolean;
}

export interface Column {
  id: string;
  board_id: string;
  name: string;
  position: number;
  color: string;
  settings: ColumnSettings;
  inserted_at: string;
  updated_at: string;
}

export interface Task {
  id: string;
  column_id: string;
  title: string;
  description: string | null;
  position: number;
  worktree_path: string | null;
  worktree_branch: string | null;
  custom_branch_name: string | null;
  agent_status:
    | "idle"
    | "thinking"
    | "executing"
    | "waiting_for_user"
    | "error";
  agent_status_message: string | null;
  in_progress: boolean;
  error_message: string | null;
  queued_at: string | null;
  queue_priority: number;
  pr_url: string | null;
  pr_number: number | null;
  pr_status: "open" | "merged" | "closed" | "draft" | null;
  // Parent-subtask fields
  parent_task_id: string | null;
  is_parent: boolean;
  subtask_position: number;
  subtask_generation_status: "generating" | "completed" | "failed" | null;
  // Description images
  description_images: Array<{
    id: string;
    path: string;
    name: string;
  }> | null;
  // Hook execution tracking
  hook_queue: Array<{
    id: string;
    name: string;
    status:
      | "pending"
      | "running"
      | "completed"
      | "cancelled"
      | "failed"
      | "skipped";
    skip_reason?: "error" | "disabled";
  }> | null;
  // Persistent hook execution history
  hook_history: Array<{
    id: string;
    name: string;
    status: "completed" | "failed" | "cancelled" | "skipped";
    skip_reason?: "error" | "disabled";
    error_message?: string;
    executed_at: string;
  }> | null;
  inserted_at: string;
  updated_at: string;
}

export interface Subtask {
  id: string;
  title: string;
  description: string | null;
  priority: "low" | "medium" | "high";
  column_id: string;
  position: number;
  subtask_position: number;
  agent_status:
    | "idle"
    | "thinking"
    | "executing"
    | "waiting_for_user"
    | "error";
  agent_status_message: string | null;
}

// Hook types
export type HookKind = "script" | "agent";
export type AgentExecutor =
  | "claude_code"
  | "gemini_cli"
  | "codex"
  | "opencode"
  | "cursor_agent";

export interface Hook {
  id: string;
  board_id: string;
  name: string;
  hook_kind: HookKind;
  // Script hook fields
  command: string | null;
  // Agent hook fields
  agent_prompt: string | null;
  agent_executor: AgentExecutor | null;
  agent_auto_approve: boolean;
  inserted_at: string;
  updated_at: string;
}

// System hook type (virtual hooks defined in code)
export interface SystemHook {
  id: string;
  name: string;
  description: string;
  is_system: true;
  hook_kind: "script";
  command: null;
}

// Combined hook type that can be either a database hook or a system hook
export interface CombinedHook {
  id: string;
  name: string;
  description: string | null;
  hook_kind: HookKind;
  // Script hook fields
  command: string | null;
  // Agent hook fields
  agent_prompt: string | null;
  agent_executor: AgentExecutor | null;
  agent_auto_approve: boolean;
  is_system: boolean;
  // Default settings for when this hook is added to a column
  default_execute_once: boolean;
  default_transparent: boolean;
}

export interface ColumnHook {
  id: string;
  column_id: string;
  hook_id: string;
  hook_type: "on_entry"; // Only on_entry hooks are supported
  position: number;
  execute_once: boolean;
  transparent: boolean;
  removable: boolean;
  hook_settings: Record<string, unknown>;
  inserted_at: string;
  updated_at: string;
}

export interface Repository {
  id: string;
  board_id: string;
  name: string;
  full_name: string | null;
  provider: "github" | "gitlab" | "local";
  provider_repo_id: string | null;
  clone_url: string | null;
  html_url: string | null;
  local_path: string | null;
  clone_status: "pending" | "cloning" | "cloned" | "error" | null;
  clone_error: string | null;
  default_branch: string;
  inserted_at: string;
  updated_at: string;
}

// Message type for LLM chat
export interface Message {
  id: string;
  task_id: string;
  role: "user" | "assistant" | "system";
  content: string;
  status: "pending" | "processing" | "completed" | "failed";
  metadata: Record<string, unknown>;
  sequence: number;
  inserted_at: string;
  updated_at: string;
}

// ============================================================================
// Electric Collections
// ============================================================================

/**
 * Electric SQL collections for real-time sync.
 * These use getApiBase() which returns window.location.origin in the browser,
 * ensuring all requests go through Caddy proxy for HTTP/2 support.
 */
export const boardsCollection = createCollection(
  electricCollectionOptions<Board>({
    id: "boards",
    getKey: (item) => item.id,
    shapeOptions: {
      url: `${getApiBase()}/api/shapes/boards`,
    },
  }),
);

// Column type for Electric sync (settings stored as JSON string, parsed on read)
interface ColumnRaw {
  id: string;
  board_id: string;
  name: string;
  position: number;
  color: string;
  settings: string | ColumnSettings;
  inserted_at: string;
  updated_at: string;
}

export const columnsCollection = createCollection(
  electricCollectionOptions<ColumnRaw>({
    id: "columns",
    getKey: (item) => item.id,
    shapeOptions: {
      url: `${getApiBase()}/api/shapes/columns`,
    },
  }),
);

export const tasksCollection = createCollection(
  electricCollectionOptions<Task>({
    id: "tasks",
    getKey: (item) => item.id,
    shapeOptions: {
      url: `${getApiBase()}/api/shapes/tasks`,
    },
  }),
);

export const hooksCollection = createCollection(
  electricCollectionOptions<Hook>({
    id: "hooks",
    getKey: (item) => item.id,
    shapeOptions: {
      url: `${getApiBase()}/api/shapes/hooks`,
    },
  }),
);

export const columnHooksCollection = createCollection(
  electricCollectionOptions<ColumnHook>({
    id: "column_hooks",
    getKey: (item) => item.id,
    shapeOptions: {
      url: `${getApiBase()}/api/shapes/column_hooks`,
    },
  }),
);

export const repositoriesCollection = createCollection(
  electricCollectionOptions<Repository>({
    id: "repositories",
    getKey: (item) => item.id,
    shapeOptions: {
      url: `${getApiBase()}/api/shapes/repositories`,
    },
  }),
);

export const messagesCollection = createCollection(
  electricCollectionOptions<Message>({
    id: "messages",
    getKey: (item) => item.id,
    shapeOptions: {
      url: `${getApiBase()}/api/shapes/messages`,
    },
  }),
);

// Shared hook result type to ensure consistency across all query hooks
interface QueryHookResult<T> {
  data: () => T;
  isLoading: () => boolean;
  error: () => string | null;
}

// Helper to create standardized hook results from useLiveQuery
function createQueryResult<T>(
  query: ReturnType<typeof useLiveQuery>,
  defaultValue: T,
): QueryHookResult<T> {
  return {
    data: () => (query.data as T | undefined) ?? defaultValue,
    isLoading: () => query.isLoading(),
    error: () => (query.isError() ? String(query.status()) : null),
  };
}

// Hooks
export function useBoards() {
  const query = useLiveQuery((q) =>
    q.from({ boards: boardsCollection }).select(({ boards }) => ({
      id: boards.id,
      name: boards.name,
      description: boards.description,
      inserted_at: boards.inserted_at,
      updated_at: boards.updated_at,
    })),
  );

  const result = createQueryResult<Board[] | undefined>(query, undefined);
  return {
    boards: result.data,
    isLoading: result.isLoading,
    error: result.error,
  };
}

export function useBoard(boardId: () => string | undefined) {
  const query = useLiveQuery((q) => {
    const id = boardId();
    if (!id) return undefined;

    return q
      .from({ boards: boardsCollection })
      .where(({ boards }) => eq(boards.id, id))
      .select(({ boards }) => ({
        id: boards.id,
        name: boards.name,
        description: boards.description,
        inserted_at: boards.inserted_at,
        updated_at: boards.updated_at,
      }));
  });

  const result = createQueryResult<Board[]>(query, []);
  return {
    board: () => (result.data().length > 0 ? result.data()[0] : null),
    isLoading: result.isLoading,
    error: result.error,
  };
}

// Helper to parse settings from raw column data
function parseColumnSettings(
  settings: string | ColumnSettings,
): ColumnSettings {
  if (typeof settings === "string") {
    try {
      return JSON.parse(settings) as ColumnSettings;
    } catch {
      return {};
    }
  }
  return settings || {};
}

export function useColumns(boardId: () => string | undefined) {
  const query = useLiveQuery((q) => {
    const id = boardId();
    if (!id) return undefined;

    return q
      .from({ columns: columnsCollection })
      .where(({ columns }) => eq(columns.board_id, id))
      .orderBy(({ columns }) => columns.position, "asc")
      .select(({ columns }) => ({
        id: columns.id,
        board_id: columns.board_id,
        name: columns.name,
        position: columns.position,
        color: columns.color,
        settings: columns.settings,
        inserted_at: columns.inserted_at,
        updated_at: columns.updated_at,
      }));
  });

  const result = createQueryResult<ColumnRaw[]>(query, []);
  return {
    columns: (): Column[] =>
      result.data().map((col) => ({
        ...col,
        settings: parseColumnSettings(col.settings),
      })),
    isLoading: result.isLoading,
    error: result.error,
  };
}

// Shared task selection fields to avoid duplication across useTasks and useAllTasks
type TaskQueryFields = {
  tasks: {
    id: string;
    column_id: string;
    title: string;
    description: string | null;
    position: number;
    worktree_path: string | null;
    worktree_branch: string | null;
    custom_branch_name: string | null;
    agent_status: Task["agent_status"];
    agent_status_message: string | null;
    in_progress: boolean;
    error_message: string | null;
    parent_task_id: string | null;
    is_parent: boolean;
    subtask_position: number;
    subtask_generation_status: Task["subtask_generation_status"];
    inserted_at: string;
    updated_at: string;
  };
};

// Shared select function for task queries
const selectTaskFields = ({ tasks }: TaskQueryFields) => ({
  id: tasks.id,
  column_id: tasks.column_id,
  title: tasks.title,
  description: tasks.description,
  position: tasks.position,
  worktree_path: tasks.worktree_path,
  worktree_branch: tasks.worktree_branch,
  custom_branch_name: tasks.custom_branch_name,
  agent_status: tasks.agent_status,
  agent_status_message: tasks.agent_status_message,
  in_progress: tasks.in_progress,
  error_message: tasks.error_message,
  parent_task_id: tasks.parent_task_id,
  is_parent: tasks.is_parent,
  subtask_position: tasks.subtask_position,
  subtask_generation_status: tasks.subtask_generation_status,
  inserted_at: tasks.inserted_at,
  updated_at: tasks.updated_at,
});

export function useTasks(columnId: () => string | undefined) {
  const query = useLiveQuery((q) => {
    const id = columnId();
    if (!id) return undefined;

    return q
      .from({ tasks: tasksCollection })
      .where(({ tasks }) => eq(tasks.column_id, id))
      .orderBy(({ tasks }) => tasks.position, "asc")
      .select(selectTaskFields);
  });

  const result = createQueryResult<Task[]>(query, []);
  return {
    tasks: result.data,
    isLoading: result.isLoading,
    error: result.error,
  };
}

export function useAllTasks(boardId: () => string | undefined) {
  const { columns } = useColumns(boardId);

  const query = useLiveQuery((q) => {
    const cols = columns();
    if (!cols || cols.length === 0) return undefined;

    const columnIds = cols.map((c) => c.id);
    return q
      .from({ tasks: tasksCollection })
      .where(({ tasks }) => inArray(tasks.column_id, columnIds))
      .orderBy(({ tasks }) => tasks.position, "asc")
      .select(selectTaskFields);
  });

  const result = createQueryResult<Task[]>(query, []);
  return {
    tasks: result.data,
    isLoading: result.isLoading,
    error: result.error,
  };
}

// ============================================================================
// RPC Mutation Functions
// ============================================================================

/** Response structure from RPC API calls */
interface RpcResponse<T> {
  ok: boolean;
  result?: T;
  error?: string;
}

/**
 * Type guard to validate RPC response structure.
 */
function isRpcResponse<T>(data: unknown): data is RpcResponse<T> {
  return (
    typeof data === "object" &&
    data !== null &&
    "ok" in data &&
    typeof (data as RpcResponse<T>).ok === "boolean"
  );
}

/**
 * Makes an RPC call to the backend API.
 *
 * @param domain - The Ash domain (e.g., "Kanban")
 * @param resource - The Ash resource (e.g., "Task", "Board")
 * @param action - The action to perform (e.g., "create", "update")
 * @param input - Optional input parameters for the action
 * @param id - Optional resource ID for update/delete operations
 * @param validator - Optional type guard to validate the response
 */
async function rpcCall<T>(
  domain: string,
  resource: string,
  action: string,
  input?: object,
  id?: string,
  validator?: (data: unknown) => data is T,
): Promise<T> {
  const response = await fetch("/api/rpc/run", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      domain,
      resource,
      action,
      input: input ?? {},
      ...(id && { id }),
    }),
  });

  const data: unknown = await response.json();

  if (!isRpcResponse<T>(data)) {
    throw new Error("Invalid response from server");
  }

  if (!data.ok) {
    throw new Error(data.error ?? "Unknown error");
  }

  // Result is guaranteed to exist when ok is true by the API contract
  const result = data.result as T;

  // If a validator is provided, validate the result at runtime
  if (validator && !validator(result)) {
    console.warn("[rpcCall] Response validation failed for:", resource, action);
    throw new Error(`Invalid ${resource} response from server`);
  }

  return result;
}

// ============================================================================
// Task Mutations
// ============================================================================

/** Image input for task descriptions */
export interface DescriptionImageInput {
  id: string;
  name: string;
  dataUrl?: string; // Only for new images
}

// Task mutations
export interface CreateTaskInput {
  title: string;
  description?: string;
  position?: number;
  column_id: string;
  custom_branch_name?: string;
  description_images?: DescriptionImageInput[];
}

export async function createTask(input: CreateTaskInput): Promise<Task> {
  return rpcCall<Task>("Kanban", "Task", "create", input, undefined, isTask);
}

export interface UpdateTaskInput {
  title?: string;
  description?: string;
  position?: number;
  custom_branch_name?: string;
  description_images?: DescriptionImageInput[];
}

export async function updateTask(
  id: string,
  input: UpdateTaskInput,
): Promise<Task> {
  return rpcCall<Task>("Kanban", "Task", "update", input, id, isTask);
}

export interface MoveTaskInput {
  column_id?: string;
  position?: number;
}

export async function moveTask(
  id: string,
  input: MoveTaskInput,
): Promise<Task> {
  return rpcCall<Task>("Kanban", "Task", "move", input, id, isTask);
}

export async function deleteTask(id: string): Promise<void> {
  await rpcCall<void>("Kanban", "Task", "destroy", undefined, id);
}

export interface RefineTaskResult {
  id: string;
  title: string;
  description: string;
}

export async function refineTask(taskId: string): Promise<RefineTaskResult> {
  const response = await fetch(`/api/tasks/${taskId}/refine`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
  });

  const data = await response.json();

  if (!data.ok) {
    throw new Error(data.error || "Failed to refine task");
  }

  return data.task;
}

// Refine task description before creation (preview mode)
export interface RefinePreviewInput {
  title: string;
  description?: string;
}

export interface RefinePreviewResult {
  refined_description: string;
}

export async function refinePreview(
  input: RefinePreviewInput,
): Promise<RefinePreviewResult> {
  const response = await fetch("/api/tasks/refine-preview", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify(input),
  });

  const data = await response.json();

  if (!data.ok) {
    throw new Error(data.error || "Failed to refine description");
  }

  return { refined_description: data.refined_description };
}

// Subtask functions
export async function generateSubtasks(taskId: string): Promise<void> {
  const response = await fetch(`/api/tasks/${taskId}/generate_subtasks`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
  });

  const data = await response.json();

  if (!data.ok) {
    throw new Error(data.error || "Failed to generate subtasks");
  }
}

export async function fetchSubtasks(taskId: string): Promise<Subtask[]> {
  const response = await fetch(`/api/tasks/${taskId}/subtasks`, {
    headers: {
      "Content-Type": "application/json",
    },
  });

  const data = await response.json();

  if (!data.ok) {
    throw new Error(data.error || "Failed to fetch subtasks");
  }

  return data.subtasks;
}

export interface CreateSubtaskInput {
  title: string;
  description?: string;
  priority?: "low" | "medium" | "high";
}

export async function createSubtask(
  parentTaskId: string,
  input: CreateSubtaskInput,
): Promise<Task> {
  return rpcCall<Task>("Kanban", "Task", "create_subtask", {
    ...input,
    parent_task_id: parentTaskId,
  });
}

// ============================================================================
// Column Mutations
// ============================================================================

export interface CreateColumnInput {
  name: string;
  position?: number;
  color?: string;
  board_id: string;
}

export async function createColumn(input: CreateColumnInput): Promise<Column> {
  return rpcCall<Column>("Kanban", "Column", "create", input);
}

export interface UpdateColumnInput {
  name?: string;
  position?: number;
  color?: string;
  settings?: ColumnSettings;
}

export async function updateColumn(
  id: string,
  input: UpdateColumnInput,
): Promise<Column> {
  return rpcCall<Column>("Kanban", "Column", "update", input, id);
}

export async function updateColumnSettings(
  id: string,
  settings: Partial<ColumnSettings>,
): Promise<Column> {
  return rpcCall<Column>(
    "Kanban",
    "Column",
    "update_settings",
    { settings },
    id,
  );
}

export async function deleteColumn(id: string): Promise<void> {
  await rpcCall<void>("Kanban", "Column", "destroy", undefined, id);
}

// ============================================================================
// Board Mutations
// ============================================================================

export interface CreateBoardInput {
  name: string;
  description?: string;
}

export async function createBoard(input: CreateBoardInput): Promise<Board> {
  return rpcCall<Board>("Kanban", "Board", "create", input);
}

export interface UpdateBoardInput {
  name?: string;
  description?: string;
}

export async function updateBoard(
  id: string,
  input: UpdateBoardInput,
): Promise<Board> {
  return rpcCall<Board>("Kanban", "Board", "update", input, id);
}

export async function deleteBoard(id: string): Promise<void> {
  await rpcCall<void>("Kanban", "Board", "destroy", undefined, id);
}

// ============================================================================
// Hook Queries & Mutations
// ============================================================================

/** Query hooks for a board */
export function useHooks(boardId: () => string | undefined) {
  const query = useLiveQuery((q) => {
    const id = boardId();
    if (!id) return undefined;

    return q
      .from({ hooks: hooksCollection })
      .where(({ hooks }) => eq(hooks.board_id, id))
      .select(({ hooks }) => ({
        id: hooks.id,
        board_id: hooks.board_id,
        name: hooks.name,
        hook_kind: hooks.hook_kind,
        command: hooks.command,
        agent_prompt: hooks.agent_prompt,
        agent_executor: hooks.agent_executor,
        agent_auto_approve: hooks.agent_auto_approve,
        inserted_at: hooks.inserted_at,
        updated_at: hooks.updated_at,
      }));
  });

  const result = createQueryResult<Hook[]>(query, []);
  return {
    hooks: result.data,
    isLoading: result.isLoading,
    error: result.error,
  };
}

export function useColumnHooks(columnId: () => string | undefined) {
  const query = useLiveQuery((q) => {
    const id = columnId();
    if (!id) return undefined;

    return q
      .from({ column_hooks: columnHooksCollection })
      .where(({ column_hooks }) => eq(column_hooks.column_id, id))
      .orderBy(({ column_hooks }) => column_hooks.position, "asc")
      .select(({ column_hooks }) => ({
        id: column_hooks.id,
        column_id: column_hooks.column_id,
        hook_id: column_hooks.hook_id,
        hook_type: column_hooks.hook_type,
        position: column_hooks.position,
        execute_once: column_hooks.execute_once,
        transparent: column_hooks.transparent,
        removable: column_hooks.removable,
        hook_settings: column_hooks.hook_settings,
        inserted_at: column_hooks.inserted_at,
        updated_at: column_hooks.updated_at,
      }));
  });

  const result = createQueryResult<ColumnHook[]>(query, []);
  return {
    columnHooks: result.data,
    isLoading: result.isLoading,
    error: result.error,
  };
}

export function useRepositories(boardId: () => string | undefined) {
  const query = useLiveQuery((q) => {
    const id = boardId();
    if (!id) return undefined;

    return q
      .from({ repositories: repositoriesCollection })
      .where(({ repositories }) => eq(repositories.board_id, id))
      .select(({ repositories }) => ({
        id: repositories.id,
        board_id: repositories.board_id,
        name: repositories.name,
        full_name: repositories.full_name,
        provider: repositories.provider,
        provider_repo_id: repositories.provider_repo_id,
        clone_url: repositories.clone_url,
        html_url: repositories.html_url,
        local_path: repositories.local_path,
        clone_status: repositories.clone_status,
        clone_error: repositories.clone_error,
        default_branch: repositories.default_branch,
        inserted_at: repositories.inserted_at,
        updated_at: repositories.updated_at,
      }));
  });

  const result = createQueryResult<Repository[]>(query, []);
  return {
    repositories: result.data,
    isLoading: result.isLoading,
    error: result.error,
  };
}

// Fetch all hooks (system + custom) for a board
export async function fetchAllHooks(boardId: string): Promise<CombinedHook[]> {
  const response = await fetch(`/api/boards/${boardId}/hooks`);
  const data = await response.json();

  if (!data.ok) {
    throw new Error(data.error || "Failed to fetch hooks");
  }

  return data.hooks;
}

// Fetch system hooks only (no board context needed)
export async function fetchSystemHooks(): Promise<CombinedHook[]> {
  const response = await fetch("/api/hooks/system");
  const data = await response.json();

  if (!data.ok) {
    throw new Error(data.error || "Failed to fetch system hooks");
  }

  return data.hooks;
}

// Hook mutations
export interface CreateScriptHookInput {
  name: string;
  command: string;
  board_id: string;
}

export interface CreateAgentHookInput {
  name: string;
  agent_prompt: string;
  agent_executor?: AgentExecutor;
  agent_auto_approve?: boolean;
  board_id: string;
}

export type CreateHookInput = CreateScriptHookInput | CreateAgentHookInput;

export async function createHook(input: CreateHookInput): Promise<Hook> {
  // Determine which action to use based on input fields
  if ("command" in input) {
    return rpcCall<Hook>("Kanban", "Hook", "create_script_hook", input);
  } else {
    return rpcCall<Hook>("Kanban", "Hook", "create_agent_hook", input);
  }
}

export async function createScriptHook(
  input: CreateScriptHookInput,
): Promise<Hook> {
  return rpcCall<Hook>("Kanban", "Hook", "create_script_hook", input);
}

export async function createAgentHook(
  input: CreateAgentHookInput,
): Promise<Hook> {
  return rpcCall<Hook>("Kanban", "Hook", "create_agent_hook", input);
}

export interface UpdateHookInput {
  name?: string;
  command?: string;
  agent_prompt?: string;
  agent_executor?: AgentExecutor;
  agent_auto_approve?: boolean;
}

export async function updateHook(
  id: string,
  input: UpdateHookInput,
): Promise<Hook> {
  return rpcCall<Hook>("Kanban", "Hook", "update", input, id);
}

export async function deleteHook(id: string): Promise<void> {
  await rpcCall<void>("Kanban", "Hook", "destroy", undefined, id);
}

// ColumnHook mutations
export interface CreateColumnHookInput {
  column_id: string;
  hook_id: string;
  position?: number;
  execute_once?: boolean;
  transparent?: boolean;
  hook_settings?: Record<string, unknown>;
}

export interface UpdateColumnHookInput {
  position?: number;
  execute_once?: boolean;
  transparent?: boolean;
  hook_settings?: Record<string, unknown>;
}

export async function createColumnHook(
  input: CreateColumnHookInput,
): Promise<ColumnHook> {
  return rpcCall<ColumnHook>("Kanban", "ColumnHook", "create", input);
}

export async function deleteColumnHook(id: string): Promise<void> {
  await rpcCall<void>("Kanban", "ColumnHook", "destroy", undefined, id);
}

export async function updateColumnHook(
  id: string,
  input: UpdateColumnHookInput,
): Promise<ColumnHook> {
  return rpcCall<ColumnHook>("Kanban", "ColumnHook", "update", input, id);
}

// Repository mutations
export interface CreateRepositoryInput {
  name: string;
  local_path: string;
  default_branch?: string;
  board_id: string;
  // Optional fields for GitHub/GitLab provider
  provider?: "github" | "gitlab" | "local";
  provider_repo_id?: string;
  full_name?: string;
  clone_url?: string;
  html_url?: string;
}

export async function createRepository(
  input: CreateRepositoryInput,
): Promise<Repository> {
  return rpcCall<Repository>("Kanban", "Repository", "create", input);
}

export interface UpdateRepositoryInput {
  name?: string;
  local_path?: string;
  default_branch?: string;
}

export async function updateRepository(
  id: string,
  input: UpdateRepositoryInput,
): Promise<Repository> {
  return rpcCall<Repository>("Kanban", "Repository", "update", input, id);
}

export async function deleteRepository(id: string): Promise<void> {
  await rpcCall<void>("Kanban", "Repository", "destroy", undefined, id);
}

// Message hook for Electric sync (alternative to channel-based real-time)
export function useMessages(taskId: () => string | undefined) {
  const query = useLiveQuery((q) => {
    const id = taskId();
    if (!id) return undefined;

    return q
      .from({ messages: messagesCollection })
      .where(({ messages }) => eq(messages.task_id, id))
      .orderBy(({ messages }) => messages.sequence, "asc")
      .select(({ messages }) => ({
        id: messages.id,
        task_id: messages.task_id,
        role: messages.role,
        content: messages.content,
        status: messages.status,
        metadata: messages.metadata,
        sequence: messages.sequence,
        inserted_at: messages.inserted_at,
        updated_at: messages.updated_at,
      }));
  });

  const result = createQueryResult<Message[]>(query, []);
  return {
    messages: result.data,
    isLoading: result.isLoading,
    error: result.error,
  };
}

// Message mutations
export interface CreateMessageInput {
  task_id: string;
  role: "user" | "assistant" | "system";
  content: string;
  status?: "pending" | "processing" | "completed" | "failed";
}

export async function createMessage(
  input: CreateMessageInput,
): Promise<Message> {
  return rpcCall<Message>("Kanban", "Message", "create", input);
}
