import { For, Show } from "solid-js";
import { useSystem } from "~/lib/SystemContext";
import { type SystemTool, type ToolCategory } from "~/hooks/useKanban";

interface ToolItemProps {
  tool: SystemTool;
}

function ToolItem(props: ToolItemProps) {
  return (
    <div
      class={`flex items-center justify-between p-3 rounded-lg border ${
        props.tool.available
          ? "bg-gray-800/50 border-gray-700"
          : "bg-gray-800/30 border-gray-700/50 opacity-60"
      }`}
    >
      <div class="flex items-center gap-3">
        <div
          class={`w-2 h-2 rounded-full ${
            props.tool.available ? "bg-green-500" : "bg-gray-500"
          }`}
        />
        <div>
          <div class="flex items-center gap-2">
            <span class="font-medium text-white">
              {props.tool.display_name}
            </span>
            <Show when={props.tool.version}>
              <span class="text-xs text-gray-500">v{props.tool.version}</span>
            </Show>
          </div>
          <Show when={props.tool.description}>
            <p class="text-xs text-gray-400 mt-0.5">{props.tool.description}</p>
          </Show>
        </div>
      </div>
      <div class="flex items-center gap-2">
        <Show when={props.tool.feature}>
          <span class="text-xs px-2 py-0.5 rounded-full bg-gray-700 text-gray-300">
            {props.tool.feature}
          </span>
        </Show>
        <span
          class={`text-xs px-2 py-0.5 rounded ${
            props.tool.available
              ? "bg-green-900/50 text-green-400"
              : "bg-gray-700/50 text-gray-500"
          }`}
        >
          {props.tool.available ? "Available" : "Not Found"}
        </span>
      </div>
    </div>
  );
}

interface ToolCategorySectionProps {
  title: string;
  tools: SystemTool[];
  category: ToolCategory;
}

function ToolCategorySection(props: ToolCategorySectionProps) {
  const filteredTools = () =>
    props.tools.filter((t) => t.category === props.category);

  return (
    <Show when={filteredTools().length > 0}>
      <div class="space-y-2">
        <h4 class="text-sm font-medium text-gray-400 flex items-center gap-2">
          {props.title}
          <span class="text-xs text-gray-500">
            ({filteredTools().filter((t) => t.available).length}/
            {filteredTools().length} available)
          </span>
        </h4>
        <div class="space-y-2">
          <For each={filteredTools()}>{(tool) => <ToolItem tool={tool} />}</For>
        </div>
      </div>
    </Show>
  );
}

export default function SystemToolsPanel() {
  const { tools, toolsLoading, toolsError } = useSystem();

  return (
    <div class="space-y-6">
      <div>
        <h3 class="text-sm font-medium text-gray-400 mb-1">
          System Tools Status
        </h3>
        <p class="text-xs text-gray-500">
          These CLI tools provide additional functionality. Install missing
          tools to unlock features.
        </p>
      </div>

      <Show
        when={!toolsLoading()}
        fallback={
          <div class="text-center py-8">
            <div class="animate-spin w-6 h-6 border-2 border-brand-500 border-t-transparent rounded-full mx-auto" />
            <p class="text-sm text-gray-400 mt-2">Loading tools...</p>
          </div>
        }
      >
        <Show
          when={!toolsError()}
          fallback={
            <div class="p-4 bg-red-900/20 border border-red-800 rounded-lg text-red-400 text-sm">
              Failed to load system tools: {toolsError()}
            </div>
          }
        >
          <div class="space-y-6">
            <ToolCategorySection
              title="Core Tools (Required)"
              tools={tools()}
              category="core"
            />

            <ToolCategorySection
              title="Optional Tools"
              tools={tools()}
              category="optional"
            />

            <Show when={tools().length === 0}>
              <div class="text-gray-500 text-sm text-center py-4">
                No tools detected.
              </div>
            </Show>
          </div>
        </Show>
      </Show>
    </div>
  );
}
