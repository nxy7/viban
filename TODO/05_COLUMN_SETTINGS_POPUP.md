# Feature: Column Settings Popup

## Overview

Add a settings icon to each column header that opens a popup/modal for configuring column-specific settings. This provides a clean, contextual way to configure columns without navigating to the main board settings.

Currently, column hook assignments are managed in the global BoardSettings panel. This feature moves column-specific configuration closer to where users interact with columns.

## User Stories

1. **Access Settings**: As a user, I can click a settings icon on any column to open its settings popup.
2. **Configure Hooks**: As a user, I can assign on_entry, on_leave, and persistent hooks directly from the column settings.
3. **View Assigned Hooks**: As a user, I can see which hooks are currently assigned to the column.
4. **Quick Hook Toggle**: As a user, I can quickly enable/disable hooks without removing them.
5. **Column-Specific Settings**: As a user, I can configure other column-specific settings (name, color, etc.) from the popup.
6. **Concurrency Settings**: As a user, I can configure concurrency limits for the "In Progress" column (see Feature 06).

## Technical Design

### Column Settings Schema

Currently columns only have basic attributes. We need to add a settings field:

```elixir
# backend/lib/viban/kanban/column.ex

defmodule Viban.Kanban.Column do
  use Ash.Resource,
    otp_app: :viban,
    domain: Viban.Kanban,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "columns"
    repo Viban.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string, allow_nil?: false
    attribute :position, :integer, default: 0
    attribute :color, :string, default: "#6366f1"

    # New: Column settings as JSONB
    attribute :settings, :map do
      default %{}
      description "Column-specific settings (max_concurrent, etc.)"
    end

    timestamps()
  end

  relationships do
    belongs_to :board, Viban.Kanban.Board, allow_nil?: false
    has_many :tasks, Viban.Kanban.Task
    has_many :column_hooks, Viban.Kanban.ColumnHook
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:name, :position, :color, :settings]
      argument :board_id, :uuid, allow_nil?: false
      change manage_relationship(:board_id, :board, type: :append)
    end

    update :update do
      accept [:name, :position, :color, :settings]
    end

    # Specialized action for updating just settings
    update :update_settings do
      accept []
      argument :settings, :map, allow_nil?: false

      change fn changeset, _context ->
        new_settings = Ash.Changeset.get_argument(changeset, :settings)
        current_settings = Ash.Changeset.get_attribute(changeset, :settings) || %{}

        # Deep merge to preserve existing settings
        merged = DeepMerge.deep_merge(current_settings, new_settings)
        Ash.Changeset.change_attribute(changeset, :settings, merged)
      end
    end
  end
end
```

### Database Migration

```elixir
# backend/priv/repo/migrations/YYYYMMDDHHMMSS_add_column_settings.exs

defmodule Viban.Repo.Migrations.AddColumnSettings do
  use Ecto.Migration

  def change do
    alter table(:columns) do
      add :settings, :map, default: %{}
    end
  end
end
```

### Settings Schema Definition

```elixir
# backend/lib/viban/kanban/column_settings.ex

defmodule Viban.Kanban.ColumnSettings do
  @moduledoc """
  Defines the structure and validation for column settings.
  """

  @type t :: %{
    optional(:max_concurrent_tasks) => pos_integer() | nil,
    optional(:description) => String.t() | nil,
    optional(:auto_move_on_complete) => boolean(),
    optional(:require_confirmation) => boolean(),
    optional(:hooks_enabled) => boolean()
  }

  @doc """
  Default settings for new columns.
  """
  def defaults do
    %{
      "max_concurrent_tasks" => nil,  # nil = unlimited
      "description" => nil,
      "auto_move_on_complete" => false,
      "require_confirmation" => false,
      "hooks_enabled" => true
    }
  end

  @doc """
  Validate settings map.
  """
  def validate(settings) when is_map(settings) do
    with :ok <- validate_max_concurrent(settings["max_concurrent_tasks"]),
         :ok <- validate_booleans(settings) do
      {:ok, settings}
    end
  end

  defp validate_max_concurrent(nil), do: :ok
  defp validate_max_concurrent(n) when is_integer(n) and n >= 1, do: :ok
  defp validate_max_concurrent(_), do: {:error, "max_concurrent_tasks must be nil or >= 1"}

  defp validate_booleans(settings) do
    bool_fields = ["auto_move_on_complete", "require_confirmation", "hooks_enabled"]

    Enum.find_value(bool_fields, :ok, fn field ->
      case Map.get(settings, field) do
        nil -> nil
        val when is_boolean(val) -> nil
        _ -> {:error, "#{field} must be a boolean"}
      end
    end)
  end
end
```

### Frontend Components

#### Column Header with Settings Icon

```tsx
// frontend/src/components/KanbanColumn.tsx (updated)

import { createSignal, Show, For } from "solid-js";
import { ColumnSettingsPopup } from "./ColumnSettingsPopup";

interface Props {
  column: Column;
  tasks: Task[];
  onTaskMove: (taskId: string, columnId: string) => void;
}

export function KanbanColumn(props: Props) {
  const [showSettings, setShowSettings] = createSignal(false);
  const [settingsAnchor, setSettingsAnchor] = createSignal<HTMLElement | null>(null);

  const taskCount = () => props.tasks.length;
  const inProgressCount = () => props.tasks.filter(t => t.in_progress).length;

  return (
    <div
      class="flex flex-col min-w-[320px] max-w-[320px] bg-zinc-900 rounded-lg"
      style={{ "border-top": `3px solid ${props.column.color}` }}
    >
      {/* Header */}
      <div class="flex items-center justify-between px-3 py-2 border-b border-zinc-800">
        <div class="flex items-center gap-2">
          <h3 class="font-semibold text-zinc-100">{props.column.name}</h3>
          <span class="text-xs text-zinc-500 bg-zinc-800 px-1.5 py-0.5 rounded">
            {taskCount()}
          </span>

          {/* Show in-progress indicator for In Progress column */}
          <Show when={props.column.name === "In Progress" && inProgressCount() > 0}>
            <span class="text-xs text-blue-400 bg-blue-500/20 px-1.5 py-0.5 rounded flex items-center gap-1">
              <RunningIcon class="w-3 h-3 animate-pulse" />
              {inProgressCount()} running
            </span>
          </Show>
        </div>

        {/* Settings button */}
        <button
          ref={(el) => setSettingsAnchor(el)}
          onClick={() => setShowSettings(true)}
          class="p-1.5 text-zinc-500 hover:text-zinc-300 hover:bg-zinc-800 rounded-md transition-colors"
          title="Column settings"
        >
          <SettingsIcon class="w-4 h-4" />
        </button>
      </div>

      {/* Tasks */}
      <div class="flex-1 overflow-y-auto p-2 space-y-2">
        <For each={props.tasks}>
          {(task) => <TaskCard task={task} />}
        </For>

        <Show when={props.column.name === "TODO"}>
          <button
            onClick={() => openCreateTaskModal(props.column.id)}
            class="w-full py-2 text-sm text-zinc-500 hover:text-zinc-300
                   border border-dashed border-zinc-700 rounded-md hover:border-zinc-600"
          >
            + Add a card
          </button>
        </Show>
      </div>

      {/* Settings Popup */}
      <Show when={showSettings()}>
        <ColumnSettingsPopup
          column={props.column}
          anchor={settingsAnchor()}
          onClose={() => setShowSettings(false)}
        />
      </Show>
    </div>
  );
}
```

#### Column Settings Popup Component

```tsx
// frontend/src/components/ColumnSettingsPopup.tsx

import { createSignal, createResource, Show, For } from "solid-js";
import { Portal } from "solid-js/web";
import { useFloating, offset, flip, shift } from "@floating-ui/solid";

interface Props {
  column: Column;
  anchor: HTMLElement | null;
  onClose: () => void;
}

export function ColumnSettingsPopup(props: Props) {
  const [activeTab, setActiveTab] = createSignal<"general" | "hooks">("general");

  // Floating UI for positioning
  const [floating, setFloating] = createSignal<HTMLElement | null>(null);

  const position = useFloating(() => props.anchor, floating, {
    placement: "bottom-end",
    middleware: [offset(8), flip(), shift({ padding: 8 })],
  });

  // Click outside to close
  const handleClickOutside = (e: MouseEvent) => {
    const el = floating();
    if (el && !el.contains(e.target as Node)) {
      props.onClose();
    }
  };

  onMount(() => {
    document.addEventListener("mousedown", handleClickOutside);
    onCleanup(() => document.removeEventListener("mousedown", handleClickOutside));
  });

  return (
    <Portal>
      {/* Backdrop */}
      <div class="fixed inset-0 z-40" />

      {/* Popup */}
      <div
        ref={setFloating}
        class="fixed z-50 w-80 bg-zinc-800 border border-zinc-700 rounded-lg shadow-xl"
        style={{
          top: `${position.y ?? 0}px`,
          left: `${position.x ?? 0}px`,
        }}
      >
        {/* Header */}
        <div class="flex items-center justify-between px-4 py-3 border-b border-zinc-700">
          <h3 class="font-semibold text-zinc-100">{props.column.name} Settings</h3>
          <button
            onClick={props.onClose}
            class="text-zinc-400 hover:text-white"
          >
            <XIcon class="w-4 h-4" />
          </button>
        </div>

        {/* Tabs */}
        <div class="flex border-b border-zinc-700">
          <button
            onClick={() => setActiveTab("general")}
            class={`flex-1 px-4 py-2 text-sm font-medium ${
              activeTab() === "general"
                ? "text-white border-b-2 border-purple-500"
                : "text-zinc-400 hover:text-white"
            }`}
          >
            General
          </button>
          <button
            onClick={() => setActiveTab("hooks")}
            class={`flex-1 px-4 py-2 text-sm font-medium ${
              activeTab() === "hooks"
                ? "text-white border-b-2 border-purple-500"
                : "text-zinc-400 hover:text-white"
            }`}
          >
            Hooks
          </button>
        </div>

        {/* Content */}
        <div class="p-4">
          <Show when={activeTab() === "general"}>
            <GeneralSettings column={props.column} />
          </Show>

          <Show when={activeTab() === "hooks"}>
            <HooksSettings column={props.column} />
          </Show>
        </div>
      </div>
    </Portal>
  );
}
```

#### General Settings Tab

```tsx
// frontend/src/components/ColumnSettingsPopup/GeneralSettings.tsx

interface Props {
  column: Column;
}

export function GeneralSettings(props: Props) {
  const [name, setName] = createSignal(props.column.name);
  const [color, setColor] = createSignal(props.column.color);
  const [description, setDescription] = createSignal(props.column.settings?.description || "");
  const [isSaving, setIsSaving] = createSignal(false);

  // Check if this is the In Progress column
  const isInProgressColumn = () => props.column.name === "In Progress";

  const handleSave = async () => {
    setIsSaving(true);
    try {
      await updateColumn(props.column.id, {
        name: name(),
        color: color(),
        settings: {
          ...props.column.settings,
          description: description() || null,
        },
      });
    } finally {
      setIsSaving(false);
    }
  };

  const colors = [
    "#6366f1", // Indigo
    "#8b5cf6", // Purple
    "#ec4899", // Pink
    "#ef4444", // Red
    "#f97316", // Orange
    "#eab308", // Yellow
    "#22c55e", // Green
    "#06b6d4", // Cyan
    "#3b82f6", // Blue
    "#64748b", // Slate
  ];

  return (
    <div class="space-y-4">
      {/* Name (disabled for system columns) */}
      <div>
        <label class="block text-sm font-medium text-zinc-300 mb-1">
          Name
        </label>
        <input
          type="text"
          value={name()}
          onInput={(e) => setName(e.currentTarget.value)}
          disabled={["TODO", "In Progress", "To Review", "Done"].includes(props.column.name)}
          class="w-full px-3 py-2 bg-zinc-900 border border-zinc-700 rounded-md
                 disabled:opacity-50 disabled:cursor-not-allowed"
        />
        <Show when={["TODO", "In Progress", "To Review", "Done"].includes(props.column.name)}>
          <p class="text-xs text-zinc-500 mt-1">System columns cannot be renamed</p>
        </Show>
      </div>

      {/* Color */}
      <div>
        <label class="block text-sm font-medium text-zinc-300 mb-2">
          Color
        </label>
        <div class="flex flex-wrap gap-2">
          <For each={colors}>
            {(c) => (
              <button
                onClick={() => setColor(c)}
                class={`w-6 h-6 rounded-full transition-transform ${
                  color() === c ? "ring-2 ring-white ring-offset-2 ring-offset-zinc-800 scale-110" : ""
                }`}
                style={{ "background-color": c }}
              />
            )}
          </For>
        </div>
      </div>

      {/* Description */}
      <div>
        <label class="block text-sm font-medium text-zinc-300 mb-1">
          Description (optional)
        </label>
        <textarea
          value={description()}
          onInput={(e) => setDescription(e.currentTarget.value)}
          placeholder="What should tasks in this column be doing?"
          rows={2}
          class="w-full px-3 py-2 bg-zinc-900 border border-zinc-700 rounded-md text-sm"
        />
      </div>

      {/* Save button */}
      <button
        onClick={handleSave}
        disabled={isSaving()}
        class="w-full py-2 text-sm bg-purple-600 hover:bg-purple-700
               disabled:opacity-50 rounded-md font-medium"
      >
        {isSaving() ? "Saving..." : "Save Changes"}
      </button>
    </div>
  );
}
```

#### Hooks Settings Tab

```tsx
// frontend/src/components/ColumnSettingsPopup/HooksSettings.tsx

interface Props {
  column: Column;
}

export function HooksSettings(props: Props) {
  const [columnHooks] = createResource(() => props.column.id, fetchColumnHooks);
  const [availableHooks] = createResource(() => props.column.board_id, fetchBoardHooks);
  const [showAddHook, setShowAddHook] = createSignal(false);

  const groupedHooks = () => {
    const hooks = columnHooks() || [];
    return {
      on_entry: hooks.filter(h => h.hook_type === "on_entry"),
      on_leave: hooks.filter(h => h.hook_type === "on_leave"),
      persistent: hooks.filter(h => h.hook_type === "persistent"),
    };
  };

  return (
    <div class="space-y-4">
      {/* Hooks enabled toggle */}
      <div class="flex items-center justify-between">
        <span class="text-sm text-zinc-300">Hooks enabled</span>
        <Toggle
          checked={props.column.settings?.hooks_enabled !== false}
          onChange={(enabled) => updateColumnSettings(props.column.id, { hooks_enabled: enabled })}
        />
      </div>

      {/* On Entry Hooks */}
      <HookSection
        title="On Entry"
        description="Run when task enters this column"
        hooks={groupedHooks().on_entry}
        hookType="on_entry"
        columnId={props.column.id}
        availableHooks={availableHooks()}
      />

      {/* On Leave Hooks */}
      <HookSection
        title="On Leave"
        description="Run when task leaves this column"
        hooks={groupedHooks().on_leave}
        hookType="on_leave"
        columnId={props.column.id}
        availableHooks={availableHooks()}
      />

      {/* Persistent Hooks */}
      <HookSection
        title="Persistent"
        description="Run while task is in this column"
        hooks={groupedHooks().persistent}
        hookType="persistent"
        columnId={props.column.id}
        availableHooks={availableHooks()}
      />
    </div>
  );
}

interface HookSectionProps {
  title: string;
  description: string;
  hooks: ColumnHook[];
  hookType: "on_entry" | "on_leave" | "persistent";
  columnId: string;
  availableHooks: Hook[];
}

function HookSection(props: HookSectionProps) {
  const [showPicker, setShowPicker] = createSignal(false);

  const hookDetails = (columnHook: ColumnHook) => {
    return props.availableHooks?.find(h => h.id === columnHook.hook_id);
  };

  return (
    <div class="space-y-2">
      <div class="flex items-center justify-between">
        <div>
          <h4 class="text-sm font-medium text-zinc-200">{props.title}</h4>
          <p class="text-xs text-zinc-500">{props.description}</p>
        </div>
        <button
          onClick={() => setShowPicker(true)}
          class="text-xs text-purple-400 hover:text-purple-300"
        >
          + Add
        </button>
      </div>

      {/* Assigned hooks */}
      <div class="space-y-1">
        <Show
          when={props.hooks.length > 0}
          fallback={
            <p class="text-xs text-zinc-600 italic py-2">No hooks assigned</p>
          }
        >
          <For each={props.hooks}>
            {(columnHook) => {
              const hook = hookDetails(columnHook);
              return (
                <div class="flex items-center justify-between p-2 bg-zinc-900 rounded-md">
                  <div class="flex items-center gap-2">
                    <Show
                      when={hook?.hook_kind === "agent"}
                      fallback={<TerminalIcon class="w-3.5 h-3.5 text-zinc-400" />}
                    >
                      <SparklesIcon class="w-3.5 h-3.5 text-purple-400" />
                    </Show>
                    <span class="text-sm">{hook?.name || "Unknown Hook"}</span>
                  </div>
                  <button
                    onClick={() => removeColumnHook(columnHook.id)}
                    class="text-zinc-500 hover:text-red-400"
                  >
                    <XIcon class="w-3.5 h-3.5" />
                  </button>
                </div>
              );
            }}
          </For>
        </Show>
      </div>

      {/* Hook Picker Modal */}
      <Show when={showPicker()}>
        <HookPickerModal
          availableHooks={props.availableHooks.filter(
            h => !props.hooks.some(ch => ch.hook_id === h.id)
          )}
          onSelect={(hookId) => {
            addColumnHook(props.columnId, hookId, props.hookType);
            setShowPicker(false);
          }}
          onClose={() => setShowPicker(false)}
        />
      </Show>
    </div>
  );
}
```

#### Hook Picker Modal

```tsx
// frontend/src/components/HookPickerModal.tsx

interface Props {
  availableHooks: Hook[];
  onSelect: (hookId: string) => void;
  onClose: () => void;
}

export function HookPickerModal(props: Props) {
  return (
    <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/50">
      <div class="bg-zinc-800 rounded-lg w-96 max-h-[60vh] overflow-hidden">
        <div class="flex items-center justify-between px-4 py-3 border-b border-zinc-700">
          <h3 class="font-semibold">Select Hook</h3>
          <button onClick={props.onClose} class="text-zinc-400 hover:text-white">
            <XIcon class="w-4 h-4" />
          </button>
        </div>

        <div class="p-4 space-y-2 overflow-y-auto max-h-80">
          <Show
            when={props.availableHooks.length > 0}
            fallback={
              <p class="text-center text-zinc-500 py-4">
                No available hooks. Create one in Board Settings first.
              </p>
            }
          >
            <For each={props.availableHooks}>
              {(hook) => (
                <button
                  onClick={() => props.onSelect(hook.id)}
                  class="w-full text-left p-3 bg-zinc-900 hover:bg-zinc-700
                         rounded-md transition-colors"
                >
                  <div class="flex items-center gap-2">
                    <Show
                      when={hook.hook_kind === "agent"}
                      fallback={<TerminalIcon class="w-4 h-4 text-zinc-400" />}
                    >
                      <SparklesIcon class="w-4 h-4 text-purple-400" />
                    </Show>
                    <span class="font-medium">{hook.name}</span>
                    <span class={`text-xs px-1.5 py-0.5 rounded ${
                      hook.hook_kind === "agent"
                        ? "bg-purple-600/20 text-purple-400"
                        : "bg-zinc-700 text-zinc-400"
                    }`}>
                      {hook.hook_kind}
                    </span>
                  </div>
                  <p class="text-sm text-zinc-500 mt-1 line-clamp-2">
                    {hook.hook_kind === "agent"
                      ? hook.agent_prompt
                      : hook.command}
                  </p>
                </button>
              )}
            </For>
          </Show>
        </div>
      </div>
    </div>
  );
}
```

### API Endpoints

```elixir
# backend/lib/viban_web/router.ex - Add column settings routes

scope "/api", VibanWeb do
  pipe_through :api

  # Existing routes...

  # Column settings
  patch "/columns/:id/settings", ColumnController, :update_settings
  get "/columns/:id/hooks", ColumnHookController, :index
  post "/columns/:id/hooks", ColumnHookController, :create
  delete "/column-hooks/:id", ColumnHookController, :delete
end
```

```elixir
# backend/lib/viban_web/controllers/column_controller.ex

defmodule VibanWeb.ColumnController do
  use VibanWeb, :controller

  alias Viban.Kanban

  def update_settings(conn, %{"id" => id, "settings" => settings}) do
    column = Kanban.get_column!(id)

    case Kanban.update_column_settings(column, settings) do
      {:ok, updated} ->
        json(conn, %{column: column_json(updated)})
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_errors(changeset)})
    end
  end

  defp column_json(column) do
    %{
      id: column.id,
      name: column.name,
      position: column.position,
      color: column.color,
      settings: column.settings,
      board_id: column.board_id
    }
  end
end
```

## Visual Design

### Settings Icon Placement

```
┌─────────────────────────────────────────┐
│ ┌─────────────────────────────────────┐ │
│ │ In Progress        (3)  🔵2 ⚙️      │ │  ← Settings icon in header
│ ├─────────────────────────────────────┤ │
│ │                                     │ │
│ │  [ Task Card 1 ]                    │ │
│ │                                     │ │
│ │  [ Task Card 2 ]                    │ │
│ │                                     │ │
│ └─────────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

### Settings Popup

```
                          ┌──────────────────────────────┐
                          │ In Progress Settings      ✕ │
                          ├──────────────────────────────┤
                          │ [General] [Hooks]            │
                          ├──────────────────────────────┤
                          │                              │
                          │ Name                         │
                          │ ┌──────────────────────────┐ │
                          │ │ In Progress              │ │
                          │ └──────────────────────────┘ │
                          │                              │
                          │ Color                        │
                          │ ● ● ● ● ● ● ● ●             │
                          │                              │
                          │ Description                  │
                          │ ┌──────────────────────────┐ │
                          │ │ Tasks being worked on    │ │
                          │ └──────────────────────────┘ │
                          │                              │
                          │ ┌──────────────────────────┐ │
                          │ │      Save Changes        │ │
                          │ └──────────────────────────┘ │
                          └──────────────────────────────┘
```

### Hooks Tab

```
                          ┌──────────────────────────────┐
                          │ In Progress Settings      ✕ │
                          ├──────────────────────────────┤
                          │ [General] [Hooks]            │
                          ├──────────────────────────────┤
                          │                              │
                          │ Hooks enabled          [ON]  │
                          │                              │
                          │ On Entry               + Add │
                          │ Run when task enters         │
                          │ ┌──────────────────────────┐ │
                          │ │ 🔮 Create PR          ✕ │ │
                          │ └──────────────────────────┘ │
                          │                              │
                          │ On Leave               + Add │
                          │ Run when task leaves         │
                          │ (No hooks assigned)          │
                          │                              │
                          │ Persistent             + Add │
                          │ Run while in column          │
                          │ ┌──────────────────────────┐ │
                          │ │ 🖥️ Watch Tests        ✕ │ │
                          │ └──────────────────────────┘ │
                          │                              │
                          └──────────────────────────────┘
```

## Implementation Steps

### Phase 1: Backend Foundation (Day 1)
1. Create migration to add settings column
2. Update Column resource with settings attribute
3. Add update_settings action with merge logic
4. Create ColumnSettings module for validation

### Phase 2: API Layer (Day 1)
1. Add column settings controller/endpoint
2. Update column hook endpoints if needed
3. Test API with curl/Postman

### Phase 3: Frontend - Settings Icon (Day 2)
1. Add settings icon to KanbanColumn header
2. Create ColumnSettingsPopup shell component
3. Implement floating UI positioning
4. Add click-outside-to-close behavior

### Phase 4: Frontend - General Tab (Day 2)
1. Create GeneralSettings component
2. Implement name, color, description editing
3. Add save functionality with optimistic updates

### Phase 5: Frontend - Hooks Tab (Day 3)
1. Create HooksSettings component
2. Create HookSection component for each trigger type
3. Create HookPickerModal for adding hooks
4. Implement add/remove hook functionality

### Phase 6: Polish (Day 3)
1. Add loading states
2. Add animations for popup
3. Add keyboard navigation (Escape to close)
4. Test responsiveness

## Success Criteria

- [ ] Settings icon visible on all column headers
- [ ] Clicking icon opens popup aligned to column
- [ ] General tab allows editing color and description
- [ ] Hooks tab shows all assigned hooks grouped by type
- [ ] Can add new hooks from picker modal
- [ ] Can remove hooks with single click
- [ ] Popup closes on click outside or Escape
- [ ] Changes persist after page reload
- [ ] Works well with Electric sync

## Technical Considerations

1. **Popup Positioning**: Use Floating UI for smart positioning that avoids viewport edges
2. **State Sync**: Electric sync should handle column updates automatically
3. **Optimistic Updates**: Show changes immediately, rollback on error
4. **System Columns**: Prevent renaming of TODO, In Progress, To Review, Done
5. **Mobile**: Popup should work on mobile (may need fullscreen modal alternative)

## Future Enhancements

1. **Column Templates**: Save column configurations as templates
2. **Bulk Hook Management**: Apply hooks to multiple columns at once
3. **Column Cloning**: Duplicate column with all settings
4. **Column Archives**: Hide completed columns without deleting
5. **Column Metrics**: Show task throughput, average time in column
