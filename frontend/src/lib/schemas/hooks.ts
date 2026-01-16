import { z } from "zod";

export const HookKindSchema = z.enum(["script", "agent"]);
export type HookKind = z.infer<typeof HookKindSchema>;

export const AgentExecutorSchema = z.enum([
  "claude_code",
  "gemini_cli",
  "codex",
  "opencode",
  "cursor_agent",
]);
export type AgentExecutor = z.infer<typeof AgentExecutorSchema>;

export const SystemHookSchema = z.object({
  id: z.string(),
  name: z.string(),
  description: z.string(),
  is_system: z.literal(true),
  hook_kind: z.literal("script"),
  command: z.null(),
});
export type SystemHook = z.infer<typeof SystemHookSchema>;

export const CombinedHookSchema = z.object({
  id: z.string(),
  name: z.string(),
  description: z.string().nullable(),
  hook_kind: HookKindSchema,
  command: z.string().nullable(),
  agent_prompt: z.string().nullable(),
  agent_executor: AgentExecutorSchema.nullable(),
  agent_auto_approve: z.boolean().nullable(),
  is_system: z.boolean(),
  default_execute_once: z.boolean().nullable(),
  default_transparent: z.boolean().nullable(),
});
export type CombinedHook = z.infer<typeof CombinedHookSchema>;

export const PlaySoundSettingsSchema = z.object({
  sound: z.string().optional(),
});
export type PlaySoundSettings = z.infer<typeof PlaySoundSettingsSchema>;

export const MoveTaskSettingsSchema = z.object({
  target_column: z.string().optional(),
});
export type MoveTaskSettings = z.infer<typeof MoveTaskSettingsSchema>;

export const HookSettingsSchema = z.union([
  PlaySoundSettingsSchema,
  MoveTaskSettingsSchema,
  z.record(z.string(), z.unknown()),
]);
export type HookSettings = z.infer<typeof HookSettingsSchema>;

export const ColumnHookSchema = z.object({
  id: z.string(),
  column_id: z.string(),
  hook_id: z.string(),
  hook_type: z.string(),
  position: z.union([z.string(), z.number()]),
  execute_once: z.boolean().nullable(),
  transparent: z.boolean().nullable(),
  removable: z.boolean().nullable(),
  hook_settings: z.record(z.string(), z.unknown()).nullable(),
  inserted_at: z.string(),
  updated_at: z.string(),
});
export type ColumnHook = z.infer<typeof ColumnHookSchema>;

export const ColumnSettingsSchema = z.object({
  max_concurrent_tasks: z.number().nullable().optional(),
  description: z.string().nullable().optional(),
  auto_move_on_complete: z.boolean().optional(),
  require_confirmation: z.boolean().optional(),
  hooks_enabled: z.boolean().optional(),
});
export type ColumnSettings = z.infer<typeof ColumnSettingsSchema>;

export function parseColumnSettings(
  settings: unknown,
): ColumnSettings {
  if (settings === null || settings === undefined) return {};
  if (typeof settings === "string") {
    try {
      const parsed = JSON.parse(settings);
      return ColumnSettingsSchema.parse(parsed);
    } catch {
      return {};
    }
  }
  try {
    return ColumnSettingsSchema.parse(settings);
  } catch {
    return {};
  }
}

export function parseHookSettings<T extends z.ZodSchema>(
  settings: unknown,
  schema: T,
): z.infer<T> | null {
  if (settings === null || settings === undefined) return null;
  try {
    return schema.parse(settings);
  } catch {
    return null;
  }
}

export function validateCombinedHooks(data: unknown): CombinedHook[] {
  if (!Array.isArray(data)) return [];
  return data.filter((item): item is CombinedHook => {
    try {
      CombinedHookSchema.parse(item);
      return true;
    } catch {
      return false;
    }
  });
}
