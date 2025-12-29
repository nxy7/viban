# Kanban Board MVP - Implementation Plan

## Overview

Building a Kanban board application with draggable tasks, connected to Ash resources via Electric Sync for real-time updates.

**Tech Stack:**
- **Backend:** Elixir + Phoenix + Ash Framework + PostgreSQL
- **Frontend:** SolidJS + TanStack DB + Electric SQL
- **Drag & Drop:** [@thisbeyond/solid-dnd](https://github.com/thisbeyond/solid-dnd) (SolidJS-native DnD library)
- **FE/BE Contract:** AshTypescript (auto-generated types from Ash resources)

---

## Critical Architecture Rule

> **ALL frontend-backend interactions MUST go through AshTypescript.**
>
> - TypeScript types are auto-generated from Ash resources - NEVER manually define types that mirror backend models
> - Use the existing RPC controller pattern (`/api/rpc/run`) for mutations
> - Frontend calls Ash actions by domain/resource/action name
> - This ensures type safety and eliminates FE/BE contract drift

---

## Overnight Autonomous Execution Guide

This section provides guidance for running the implementation autonomously overnight.

### Execution Strategy

1. **Work in phases** - Complete backend fully before starting frontend
2. **Verify each step** - Run migrations, compile, test after each major change
3. **Commit frequently** - Create git commits after each completed task group
4. **Self-validate** - After completing a component, verify it works before moving on

### Checkpoints & Verification

After each phase, verify:

| Phase | Verification Command | Expected Result |
|-------|---------------------|-----------------|
| B1-B4 | `mix compile` | No errors |
| B5 | `mix ash.codegen && mix ecto.migrate` | Tables created |
| B6-B8 | `mix phx.routes` | Routes visible |
| B9 | `mix ash_typescript.generate` | Types in frontend |
| B10 | `mix run priv/repo/seeds.exs` | Seed data exists |
| F1 | `bun install` | Dependencies installed |
| F3-F4 | `bun run build` | No TS errors |
| F6-F9 | Start dev server, open browser | Board renders |
| F10-F11 | Test modal/panel manually | UI works |

### Error Recovery

If a step fails:
1. Read the error message carefully
2. Check existing patterns in codebase (e.g., `TestMessage` resource)
3. Fix the issue before proceeding
4. Do NOT skip steps - each depends on previous ones

### Progress Tracking

Use the TODO list to track progress. Mark items:
- `in_progress` when starting
- `completed` when verified working

### Git Commit Strategy

Create commits at these milestones:
1. After B4 - "Add Kanban Ash resources (Board, Column, Task)"
2. After B8 - "Add Kanban API routes and controllers"
3. After B10 - "Add seed data for default board"
4. After F4 - "Add Electric sync hooks for Kanban"
5. After F9 - "Add Kanban board with drag & drop"
6. After F11 - "Add task creation modal and details panel"
7. After F15 - "Complete Kanban MVP"

---

## Phase 1: Backend - Ash Resources

### 1.1 Create Board Resource

**File:** `backend/lib/viban/kanban/board.ex`

```elixir
defmodule Viban.Kanban.Board do
  use Ash.Resource,
    domain: Viban.Kanban,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshTypescript.Resource]

  postgres do
    table "boards"
    repo Viban.Repo
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false
    attribute :description, :string
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    has_many :columns, Viban.Kanban.Column
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:name, :description]
    end

    update :update do
      accept [:name, :description]
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :destroy
    define :get, action: :read, get_by: [:id]
  end
end
```

### 1.2 Create Column Resource

**File:** `backend/lib/viban/kanban/column.ex`

```elixir
defmodule Viban.Kanban.Column do
  use Ash.Resource,
    domain: Viban.Kanban,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshTypescript.Resource]

  postgres do
    table "columns"
    repo Viban.Repo
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false
    attribute :position, :integer, allow_nil?: false, default: 0
    attribute :color, :string, default: "#6366f1" # Default indigo
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :board, Viban.Kanban.Board, allow_nil?: false
    has_many :tasks, Viban.Kanban.Task
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:name, :position, :color, :board_id]
    end

    update :update do
      accept [:name, :position, :color]
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :destroy
  end
end
```

### 1.3 Create Task Resource

**File:** `backend/lib/viban/kanban/task.ex`

```elixir
defmodule Viban.Kanban.Task do
  use Ash.Resource,
    domain: Viban.Kanban,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshTypescript.Resource]

  postgres do
    table "tasks"
    repo Viban.Repo
  end

  attributes do
    uuid_primary_key :id
    attribute :title, :string, allow_nil?: false
    attribute :description, :string
    attribute :position, :integer, allow_nil?: false, default: 0
    attribute :priority, :atom, constraints: [one_of: [:low, :medium, :high]], default: :medium
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :column, Viban.Kanban.Column, allow_nil?: false
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:title, :description, :position, :priority, :column_id]
    end

    update :update do
      accept [:title, :description, :position, :priority]
    end

    # Move task to different column (for drag & drop)
    update :move do
      accept [:column_id, :position]
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :destroy
    define :move
    define :get, action: :read, get_by: [:id]
  end
end
```

### 1.4 Create Kanban Domain

**File:** `backend/lib/viban/kanban.ex`

```elixir
defmodule Viban.Kanban do
  use Ash.Domain,
    extensions: [AshTypescript.Domain]

  resources do
    resource Viban.Kanban.Board
    resource Viban.Kanban.Column
    resource Viban.Kanban.Task
  end
end
```

### 1.5 Database Migrations

Create migration files for all three tables with proper foreign keys and indexes.

### 1.6 Sync Controller Endpoints

**File:** `backend/lib/viban_web/controllers/kanban_sync_controller.ex`

Add shape endpoints for boards, columns, and tasks.

### 1.7 Kanban Controller (Mutations)

**File:** `backend/lib/viban_web/controllers/kanban_controller.ex`

REST-like endpoints for CRUD operations.

---

## Phase 2: Frontend - Core Components

### 2.1 Install Dependencies

```bash
cd frontend
bun add @thisbeyond/solid-dnd
```

### 2.2 Electric Sync Setup

**File:** `frontend/src/lib/useKanban.ts`

```typescript
import { createCollection, electricCollectionOptions } from "@tanstack/electric-db-collection";
import { useLiveQuery } from "@tanstack/solid-db";

const API_URL = "http://localhost:7771";

// Collections for real-time sync
export const boardsCollection = createCollection(
  electricCollectionOptions<Board>({
    id: "boards",
    getKey: (item) => item.id,
    shapeOptions: { url: `${API_URL}/api/shapes/boards` },
  })
);

export const columnsCollection = createCollection(
  electricCollectionOptions<Column>({
    id: "columns",
    getKey: (item) => item.id,
    shapeOptions: { url: `${API_URL}/api/shapes/columns` },
  })
);

export const tasksCollection = createCollection(
  electricCollectionOptions<Task>({
    id: "tasks",
    getKey: (item) => item.id,
    shapeOptions: { url: `${API_URL}/api/shapes/tasks` },
  })
);

// Hooks
export function useBoard(boardId: string) { /* ... */ }
export function useColumns(boardId: string) { /* ... */ }
export function useTasks(columnId: string) { /* ... */ }

// Mutations - Use RPC pattern to call Ash actions
// Example: Call Viban.Kanban.Task :create action
export async function createTask(data: CreateTaskInput) {
  return fetch(`${API_URL}/api/rpc/run`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      domain: "Viban.Kanban",
      resource: "Task",
      action: "create",
      input: data,
    }),
  }).then(r => r.json());
}

export async function updateTask(id: string, data: UpdateTaskInput) { /* similar pattern */ }
export async function moveTask(id: string, columnId: string, position: number) { /* similar pattern */ }
export async function deleteTask(id: string) { /* similar pattern */ }
```

### 2.3 TypeScript Types (Auto-Generated)

> **IMPORTANT:** Types are AUTO-GENERATED by AshTypescript. Do NOT manually create type files.

Run `mix ash_typescript.generate` in backend to generate types. They will be placed in the configured output directory.

The generated types will look like:
```typescript
// AUTO-GENERATED - DO NOT EDIT
export interface Board {
  id: string;
  name: string;
  description: string | null;
  inserted_at: string;
  updated_at: string;
}

export interface Column {
  id: string;
  board_id: string;
  name: string;
  position: number;
  color: string;
  inserted_at: string;
  updated_at: string;
}

export interface Task {
  id: string;
  column_id: string;
  title: string;
  description: string | null;
  position: number;
  priority: "low" | "medium" | "high";
  inserted_at: string;
  updated_at: string;
}
```

Import these types from the generated location in all frontend code.

### 2.4 Kanban Board Component

**File:** `frontend/src/components/KanbanBoard.tsx`

Main board container that:
- Fetches columns for a board via Electric sync
- Renders columns in order
- Sets up DnD context

### 2.5 Kanban Column Component

**File:** `frontend/src/components/KanbanColumn.tsx`

Column component that:
- Displays column header with name/color
- Renders tasks in order
- Acts as drop zone for tasks
- Has "Add Task" button

### 2.6 Task Card Component

**File:** `frontend/src/components/TaskCard.tsx`

Draggable task card that:
- Shows title, priority indicator
- Clickable to open details panel
- Draggable via solid-dnd

---

## Phase 3: Task Creation Modal

### 3.1 Modal Component

**File:** `frontend/src/components/ui/Modal.tsx`

Reusable modal with:
- Overlay backdrop
- Close on ESC / click outside
- Focus trap
- Animated enter/exit

### 3.2 Task Creation Form

**File:** `frontend/src/components/CreateTaskModal.tsx`

Form with:
- Title input (required)
- Description textarea
- Priority selector
- Submit/Cancel buttons
- Loading state during submission

---

## Phase 4: Task Details Side Panel

### 4.1 Side Panel Component

**File:** `frontend/src/components/ui/SidePanel.tsx`

Reusable slide-in panel with:
- Slide from right animation
- Close button
- Full height, fixed width

### 4.2 Task Details View

**File:** `frontend/src/components/TaskDetailsPanel.tsx`

Panel content with:
- Task title (editable)
- Description (editable, markdown support optional)
- Priority selector
- Created/Updated timestamps
- Delete button with confirmation
- Real-time sync updates

---

## Phase 5: Drag & Drop Implementation

### 5.1 DnD Context Setup

Using `@thisbeyond/solid-dnd`:

```typescript
import {
  DragDropProvider,
  DragDropSensors,
  DragOverlay,
  SortableProvider,
  createSortable,
  closestCenter,
} from "@thisbeyond/solid-dnd";
```

### 5.2 Sortable Tasks

Tasks within a column are sortable (reorderable).

### 5.3 Cross-Column Drag

Tasks can be dragged between columns, updating `column_id` and `position`.

### 5.4 Optimistic Updates

- Update UI immediately on drag end
- Call mutation in background
- Rollback on error

---

## Implementation Order (TODO List)

### Backend Tasks

- [ ] **B1:** Create Kanban domain (`backend/lib/viban/kanban.ex`)
- [ ] **B2:** Create Board resource with attributes and actions
- [ ] **B3:** Create Column resource with board relationship
- [ ] **B4:** Create Task resource with column relationship and move action
- [ ] **B5:** Generate and run database migrations
- [ ] **B6:** Add Kanban sync controller with shape endpoints
- [ ] **B7:** Add routes for sync shapes (mutations use existing `/api/rpc/run`)
- [ ] **B8:** Generate TypeScript types with AshTypescript
- [ ] **B9:** Seed default board with columns (To Do, In Progress, Done)

### Frontend Tasks

- [ ] **F1:** Install `@thisbeyond/solid-dnd` dependency
- [ ] **F2:** Import auto-generated types from AshTypescript output (DO NOT manually create)
- [ ] **F3:** Create Electric collections and hooks (`useKanban.ts`)
- [ ] **F4:** Create RPC mutation functions using `/api/rpc/run` endpoint
- [ ] **F5:** Create base UI components (Modal, SidePanel)
- [ ] **F6:** Create KanbanBoard component with DnD provider
- [ ] **F7:** Create KanbanColumn component as drop zone
- [ ] **F8:** Create TaskCard component as draggable
- [ ] **F9:** Implement drag & drop with position updates
- [ ] **F10:** Create CreateTaskModal with form
- [ ] **F11:** Create TaskDetailsPanel with edit capabilities
- [ ] **F12:** Add board route/page (`/board/:id`)
- [ ] **F13:** Style all components with Tailwind
- [ ] **F14:** Add loading and error states
- [ ] **F15:** Test real-time sync between multiple browsers

---

## File Structure After Implementation

```
backend/
├── lib/
│   ├── viban/
│   │   ├── kanban.ex                    # Domain
│   │   └── kanban/
│   │       ├── board.ex                 # Board resource
│   │       ├── column.ex                # Column resource
│   │       └── task.ex                  # Task resource
│   └── viban_web/
│       ├── controllers/
│       │   ├── kanban_sync_controller.ex
│       │   └── kanban_controller.ex
│       └── router.ex                    # Updated routes
├── priv/
│   └── repo/
│       └── migrations/
│           ├── *_create_boards.exs
│           ├── *_create_columns.exs
│           └── *_create_tasks.exs

frontend/
├── src/
│   ├── components/
│   │   ├── ui/
│   │   │   ├── Modal.tsx
│   │   │   └── SidePanel.tsx
│   │   ├── KanbanBoard.tsx
│   │   ├── KanbanColumn.tsx
│   │   ├── TaskCard.tsx
│   │   ├── CreateTaskModal.tsx
│   │   └── TaskDetailsPanel.tsx
│   ├── lib/
│   │   └── useKanban.ts
│   ├── types/
│   │   └── kanban.ts
│   └── routes/
│       ├── index.tsx
│       └── board/
│           └── [id].tsx
```

---

## Quality Guidelines

### Code Quality
1. **Type Safety:** Full TypeScript coverage, no `any` types
2. **Error Handling:** Graceful error states with user feedback
3. **Loading States:** Skeleton loaders during data fetching
4. **Accessibility:** Keyboard navigation, ARIA labels for DnD
5. **Responsive:** Mobile-friendly column layout

### Performance
1. **Optimistic Updates:** Immediate UI feedback on mutations
2. **Efficient Queries:** Filter tasks by column on backend
3. **Memoization:** Use `createMemo` for derived state

### Testing
1. **E2E Tests:** Playwright tests for drag & drop flows
2. **Unit Tests:** Vitest for utility functions

---

## API Endpoints Summary

### Sync (GET - Electric Shapes)
- `GET /api/shapes/boards` - All boards
- `GET /api/shapes/columns` - All columns (filter by board_id)
- `GET /api/shapes/tasks` - All tasks (filter by column_id)

### Mutations (All via RPC)

All mutations use the existing generic RPC endpoint:

```
POST /api/rpc/run
Content-Type: application/json

{
  "domain": "Viban.Kanban",
  "resource": "Task",
  "action": "create",
  "input": { "title": "New Task", "column_id": "..." }
}
```

Available actions:
- `Task.create` - Create a new task
- `Task.update` - Update task fields
- `Task.move` - Move task to different column with new position
- `Task.destroy` - Delete a task
- `Column.create/update/destroy` - Column management
- `Board.create/update/destroy` - Board management

---

## Notes

- **solid-dnd** is chosen over alternatives because it's specifically built for SolidJS and integrates with its reactivity system
- Electric Sync provides real-time updates without WebSocket boilerplate
- Ash Framework handles all CRUD operations with minimal code
- Position field uses integers; rebalancing may be needed for large boards
