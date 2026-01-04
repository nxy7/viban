import { For, Show } from "solid-js";
import { type Column, useColumns } from "~/hooks/useKanban";
import { Button } from "~/components/design-system";
import ColumnHookConfig from "./ColumnHookConfig";
import HookManager from "./HookManager";
import RepositoryConfig from "./RepositoryConfig";
import SystemToolsPanel from "./SystemToolsPanel";
import SidePanel from "./ui/SidePanel";

type TabId = "general" | "hooks" | "columns" | "system";

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

  // Use prop for active tab, default to "general"
  const activeTab = () => props.activeTab ?? "general";

  const tabs: { id: TabId; label: string }[] = [
    { id: "general", label: "General" },
    { id: "hooks", label: "Hooks" },
    { id: "columns", label: "Column Hooks" },
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

        <Show when={activeTab() === "system"}>
          <SystemToolsPanel />
        </Show>
      </div>
    </SidePanel>
  );
}
