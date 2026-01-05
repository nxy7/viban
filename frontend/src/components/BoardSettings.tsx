import { eq } from "@tanstack/db";
import { useLiveQuery } from "@tanstack/solid-db";
import { createMemo, For, Show } from "solid-js";
import { Button } from "~/components/design-system";
import {
  type AgentExecutor,
  type Column,
  unwrap,
  useColumns,
} from "~/hooks/useKanban";
import * as sdk from "~/lib/generated/ash";
import {
  syncPeriodicalTasksCollection,
  syncTaskTemplatesCollection,
} from "~/lib/generated/sync/collections";
import ColumnHookConfig from "./ColumnHookConfig";
import HookManager from "./HookManager";
import PeriodicalTasksConfig from "./PeriodicalTasksConfig";
import RepositoryConfig from "./RepositoryConfig";
import SystemToolsPanel from "./SystemToolsPanel";
import TaskTemplatesConfig from "./TaskTemplatesConfig";
import SidePanel from "./ui/SidePanel";

type TabId =
  | "general"
  | "templates"
  | "hooks"
  | "columns"
  | "scheduled"
  | "system";

interface BoardSettingsProps {
  isOpen: boolean;
  onClose: () => void;
  boardId: string;
  boardName: string;
  /** Current active tab (controlled via URL) */
  activeTab?: TabId;
  /** Called when tab changes (to update URL) */
  onTabChange?: (tab: TabId) => void;
}

export default function BoardSettings(props: BoardSettingsProps) {
  const { columns } = useColumns(() => props.boardId);

  const periodicalTasksQuery = useLiveQuery((q) => {
    if (!props.boardId) return undefined;
    return q
      .from({ tasks: syncPeriodicalTasksCollection })
      .where(({ tasks }) => eq(tasks.board_id, props.boardId))
      .select(({ tasks }) => ({
        id: tasks.id,
        title: tasks.title,
        description: tasks.description,
        schedule: tasks.schedule,
        executor: tasks.executor,
        execution_count: tasks.execution_count,
        last_executed_at: tasks.last_executed_at,
        next_execution_at: tasks.next_execution_at,
        enabled: tasks.enabled,
        board_id: tasks.board_id,
      }));
  });

  const periodicalTasks = createMemo(() => {
    const data = periodicalTasksQuery.data;
    if (!Array.isArray(data)) return [];
    return data as Array<{
      id: string;
      title: string;
      description: string | null;
      schedule: string;
      executor: AgentExecutor;
      execution_count: number;
      last_executed_at: string | null;
      next_execution_at: string | null;
      enabled: boolean;
      board_id: string;
    }>;
  });

  const handleCreatePeriodicalTask = async (task: {
    title: string;
    description: string;
    schedule: string;
    executor: AgentExecutor;
  }) => {
    await sdk
      .create_periodical_task({
        input: {
          title: task.title,
          description: task.description || null,
          schedule: task.schedule,
          executor: task.executor,
          board_id: props.boardId,
        },
      })
      .then(unwrap);
  };

  const handleUpdatePeriodicalTask = async (
    id: string,
    updates: Partial<{
      title: string;
      description: string;
      schedule: string;
      executor: AgentExecutor;
      enabled: boolean;
    }>,
  ) => {
    await sdk
      .update_periodical_task({
        identity: id,
        input: updates,
      })
      .then(unwrap);
  };

  const handleDeletePeriodicalTask = async (id: string) => {
    await sdk.destroy_periodical_task({ identity: id }).then(unwrap);
  };

  const taskTemplatesQuery = useLiveQuery((q) => {
    if (!props.boardId) return undefined;
    return q
      .from({ templates: syncTaskTemplatesCollection })
      .where(({ templates }) => eq(templates.board_id, props.boardId))
      .select(({ templates }) => ({
        id: templates.id,
        name: templates.name,
        description_template: templates.description_template,
        position: templates.position,
        board_id: templates.board_id,
      }));
  });

  const taskTemplates = createMemo(() => {
    const data = taskTemplatesQuery.data;
    if (!Array.isArray(data)) return [];
    return data as Array<{
      id: string;
      name: string;
      description_template: string | null;
      position: number;
      board_id: string;
    }>;
  });

  const handleCreateTaskTemplate = async (template: {
    name: string;
    description_template: string;
  }) => {
    const maxPosition = taskTemplates().reduce(
      (max, t) => Math.max(max, t.position),
      -1,
    );
    await sdk
      .create_task_template({
        input: {
          name: template.name,
          description_template: template.description_template || null,
          position: maxPosition + 1,
          board_id: props.boardId,
        },
      })
      .then(unwrap);
  };

  const handleUpdateTaskTemplate = async (
    id: string,
    updates: Partial<{
      name: string;
      description_template: string;
      position: number;
    }>,
  ) => {
    await sdk
      .update_task_template({
        identity: id,
        input: updates,
      })
      .then(unwrap);
  };

  const handleDeleteTaskTemplate = async (id: string) => {
    await sdk.destroy_task_template({ identity: id }).then(unwrap);
  };

  // Use prop for active tab, default to "general"
  const activeTab = () => props.activeTab ?? "general";

  const tabs: { id: TabId; label: string }[] = [
    { id: "general", label: "General" },
    { id: "templates", label: "Templates" },
    { id: "hooks", label: "Hooks" },
    { id: "columns", label: "Column Hooks" },
    { id: "scheduled", label: "Scheduled" },
    { id: "system", label: "System" },
  ];

  return (
    <SidePanel
      isOpen={props.isOpen}
      onClose={props.onClose}
      title={`${props.boardName} Settings`}
      width="lg"
    >
      {/* Tab Navigation */}
      <div class="flex border-b border-gray-700 mb-4 -mx-6 px-6">
        <For each={tabs}>
          {(tab) => (
            <Button
              onClick={() => props.onTabChange?.(tab.id)}
              variant="ghost"
              buttonSize="sm"
            >
              <span
                class={`border-b-2 pb-1 transition-colors ${
                  activeTab() === tab.id
                    ? "border-brand-500 text-brand-400"
                    : "border-transparent text-gray-400"
                }`}
              >
                {tab.label}
              </span>
            </Button>
          )}
        </For>
      </div>

      {/* Tab Content */}
      <div class="space-y-6">
        <Show when={activeTab() === "general"}>
          <div class="space-y-6">
            {/* Board Info */}
            <div>
              <h3 class="text-sm font-medium text-gray-400 mb-3">
                Board Information
              </h3>
              <div class="p-4 bg-gray-800/50 border border-gray-700 rounded-lg">
                <div class="text-white font-medium">{props.boardName}</div>
                <div class="text-xs text-gray-500 mt-1">
                  Board ID: {props.boardId}
                </div>
              </div>
            </div>

            {/* Repository Section */}
            <div>
              <h3 class="text-sm font-medium text-gray-400 mb-3">Repository</h3>
              <RepositoryConfig boardId={props.boardId} singleMode={true} />
            </div>
          </div>
        </Show>

        <Show when={activeTab() === "templates"}>
          <TaskTemplatesConfig
            boardId={props.boardId}
            templates={taskTemplates()}
            onCreate={handleCreateTaskTemplate}
            onUpdate={handleUpdateTaskTemplate}
            onDelete={handleDeleteTaskTemplate}
          />
        </Show>

        <Show when={activeTab() === "hooks"}>
          <HookManager boardId={props.boardId} />
        </Show>

        <Show when={activeTab() === "columns"}>
          <div class="space-y-4">
            <p class="text-sm text-gray-400">
              Configure which hooks run when tasks enter each column.
            </p>

            <div class="space-y-4">
              <For each={columns()}>
                {(column: Column) => (
                  <div class="p-4 bg-gray-800/50 border border-gray-700 rounded-lg">
                    <ColumnHookConfig
                      boardId={props.boardId}
                      columnId={column.id}
                      columnName={column.name}
                    />
                  </div>
                )}
              </For>
            </div>

            <Show when={columns().length === 0}>
              <div class="text-gray-500 text-sm text-center py-4">
                No columns found for this board.
              </div>
            </Show>
          </div>
        </Show>

        <Show when={activeTab() === "scheduled"}>
          <PeriodicalTasksConfig
            boardId={props.boardId}
            periodicalTasks={periodicalTasks()}
            onCreate={handleCreatePeriodicalTask}
            onUpdate={handleUpdatePeriodicalTask}
            onDelete={handleDeletePeriodicalTask}
          />
        </Show>

        <Show when={activeTab() === "system"}>
          <SystemToolsPanel />
        </Show>
      </div>
    </SidePanel>
  );
}
