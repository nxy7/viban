import { z } from 'zod';

export const messageQueueEntrySchema = z.object({
  id: z.string(),
  prompt: z.string(),
  executor_type: z.enum(["claude_code", "gemini_cli"]),
  images: z.array(z.record(z.string(), z.unknown())).nullable(),
  queued_at: z.string()
});
export type MessageQueueEntry = z.infer<typeof messageQueueEntrySchema>;

export const kanbanBoardSchema = z.object({
  id: z.string().uuid(),
  name: z.string(),
  description: z.string().nullable(),
  inserted_at: z.string().datetime(),
  updated_at: z.string().datetime(),
  user_id: z.string().uuid()
});
export type KanbanBoard = z.infer<typeof kanbanBoardSchema>;

export const kanbanColumnSchema = z.object({
  id: z.string().uuid(),
  name: z.string(),
  position: z.number().int(),
  color: z.string().nullable(),
  settings: z.record(z.string(), z.unknown()).nullable(),
  inserted_at: z.string().datetime(),
  updated_at: z.string().datetime(),
  board_id: z.string().uuid()
});
export type KanbanColumn = z.infer<typeof kanbanColumnSchema>;

export const kanbanTaskSchema = z.object({
  id: z.string().uuid(),
  title: z.string(),
  description: z.string().nullable(),
  position: z.number(),
  priority: z.enum(["low", "medium", "high"]).nullable(),
  description_images: z.array(z.record(z.string(), z.unknown())).nullable(),
  worktree_path: z.string().nullable(),
  worktree_branch: z.string().nullable(),
  custom_branch_name: z.string().nullable(),
  agent_status: z.enum(["idle", "thinking", "executing", "error"]).nullable(),
  agent_status_message: z.string().nullable(),
  in_progress: z.boolean().nullable(),
  error_message: z.string().nullable(),
  queued_at: z.string().datetime().nullable(),
  queue_priority: z.number().int().nullable(),
  pr_url: z.string().nullable(),
  pr_number: z.number().int().nullable(),
  pr_status: z.enum(["open", "merged", "closed", "draft"]).nullable(),
  is_parent: z.boolean().nullable(),
  subtask_position: z.number().int().nullable(),
  subtask_generation_status: z.enum(["generating", "completed", "failed"]).nullable(),
  executed_hooks: z.array(z.string()).nullable(),
  message_queue: z.array(messageQueueEntrySchema).nullable(),
  auto_start: z.boolean(),
  inserted_at: z.string().datetime(),
  updated_at: z.string().datetime(),
  column_id: z.string().uuid(),
  parent_task_id: z.string().uuid().nullable(),
  periodical_task_id: z.string().uuid().nullable()
});
export type KanbanTask = z.infer<typeof kanbanTaskSchema>;

export const kanbanHookSchema = z.object({
  id: z.string().uuid(),
  name: z.string(),
  hook_kind: z.enum(["script", "agent"]),
  command: z.string().nullable(),
  agent_prompt: z.string().nullable(),
  agent_executor: z.enum(["claude_code", "gemini_cli", "codex", "opencode", "cursor_agent"]).nullable(),
  agent_auto_approve: z.boolean().nullable(),
  default_execute_once: z.boolean().nullable(),
  default_transparent: z.boolean().nullable(),
  inserted_at: z.string().datetime(),
  updated_at: z.string().datetime(),
  board_id: z.string().uuid()
});
export type KanbanHook = z.infer<typeof kanbanHookSchema>;

export const kanbanColumnHookSchema = z.object({
  id: z.string().uuid(),
  hook_id: z.string(),
  hook_type: z.enum(["on_entry"]),
  position: z.number().int().nullable(),
  execute_once: z.boolean().nullable(),
  hook_settings: z.record(z.string(), z.unknown()).nullable(),
  transparent: z.boolean().nullable(),
  removable: z.boolean().nullable(),
  inserted_at: z.string().datetime(),
  updated_at: z.string().datetime(),
  column_id: z.string().uuid()
});
export type KanbanColumnHook = z.infer<typeof kanbanColumnHookSchema>;

export const kanbanRepositorySchema = z.object({
  id: z.string().uuid(),
  provider: z.enum(["github", "gitlab", "local"]),
  provider_repo_id: z.string().nullable(),
  name: z.string(),
  full_name: z.string().nullable(),
  clone_url: z.string().nullable(),
  html_url: z.string().nullable(),
  default_branch: z.string().nullable(),
  local_path: z.string().nullable(),
  clone_status: z.enum(["pending", "cloning", "cloned", "error"]).nullable(),
  clone_error: z.string().nullable(),
  inserted_at: z.string().datetime(),
  updated_at: z.string().datetime(),
  board_id: z.string().uuid()
});
export type KanbanRepository = z.infer<typeof kanbanRepositorySchema>;

export const kanbanTaskEventSchema = z.object({
  id: z.string().uuid(),
  type: z.enum(["message", "hook_execution", "session", "executor_output"]),
  status: z.enum(["pending", "processing", "running", "completed", "failed", "cancelled", "skipped", "stopped"]).nullable(),
  role: z.enum(["user", "assistant", "system", "tool"]).nullable(),
  content: z.string().nullable(),
  hook_name: z.string().nullable(),
  hook_id: z.string().nullable(),
  hook_settings: z.record(z.string(), z.unknown()).nullable(),
  skip_reason: z.enum(["error", "disabled", "column_change", "server_restart", "user_cancelled"]).nullable(),
  error_message: z.string().nullable(),
  queued_at: z.string().datetime().nullable(),
  started_at: z.string().datetime().nullable(),
  completed_at: z.string().datetime().nullable(),
  triggering_column_id: z.string().uuid().nullable(),
  executor_type: z.enum(["claude_code", "gemini_cli", "codex", "opencode", "api_anthropic", "api_openai"]).nullable(),
  prompt: z.string().nullable(),
  exit_code: z.number().int().nullable(),
  working_directory: z.string().nullable(),
  session_id: z.string().uuid().nullable(),
  sequence: z.number().int().nullable(),
  metadata: z.record(z.string(), z.unknown()).nullable(),
  inserted_at: z.string().datetime(),
  updated_at: z.string().datetime(),
  task_id: z.string().uuid(),
  column_hook_id: z.string().uuid().nullable()
});
export type KanbanTaskEvent = z.infer<typeof kanbanTaskEventSchema>;

export const kanbanPeriodicalTaskSchema = z.object({
  id: z.string().uuid(),
  title: z.string(),
  description: z.string().nullable(),
  schedule: z.string(),
  executor: z.enum(["claude_code", "gemini_cli", "codex", "opencode", "cursor_agent"]).nullable(),
  execution_count: z.number().int(),
  last_executed_at: z.string().datetime().nullable(),
  next_execution_at: z.string().datetime().nullable(),
  enabled: z.boolean(),
  last_created_task_id: z.string().uuid().nullable(),
  inserted_at: z.string().datetime(),
  updated_at: z.string().datetime(),
  board_id: z.string().uuid()
});
export type KanbanPeriodicalTask = z.infer<typeof kanbanPeriodicalTaskSchema>;

export const kanbanTaskTemplateSchema = z.object({
  id: z.string().uuid(),
  name: z.string(),
  description_template: z.string().nullable(),
  position: z.number().int(),
  inserted_at: z.string().datetime(),
  updated_at: z.string().datetime(),
  board_id: z.string().uuid()
});
export type KanbanTaskTemplate = z.infer<typeof kanbanTaskTemplateSchema>;

export const stateServerActorStateSchema = z.object({
  id: z.string().uuid(),
  actor_type: z.string(),
  actor_id: z.string(),
  state: z.record(z.string(), z.unknown()),
  status: z.enum(["starting", "ok", "stopping", "stopped", "error"]),
  message: z.string().nullable(),
  version: z.number().int(),
  inserted_at: z.string().datetime(),
  updated_at: z.string().datetime()
});
export type StateServerActorState = z.infer<typeof stateServerActorStateSchema>;

