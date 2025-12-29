# Board View

The main kanban board interface where users manage tasks across columns.

## Core Layout

- **Header**: Board name, settings button, repository info
- **Columns**: Horizontal scrollable list of columns (TODO, In Progress, To Review, Done, Cancelled)
- **Task Cards**: Draggable cards within columns

## Board-Level Features

### Board Management
- View/edit board name
- Filter visible Tasks using text input at the top bar
- Access board settings panel
- See linked repository information

### Column Operations
- Reorder columns via drag-and-drop
- Add new columns
- Edit column name, color, position
- Delete columns (with confirmation)
- Toggle hooks enabled/disabled per column
- Configure column hooks (add, remove, reorder)

### Task Creation
- "Create Task" button opens modal
- Modal fields: title, description (markdown), branch name (auto-populated from title)
- Task templates: "Implement feature", "Fix bug", "Refactor code"
- Auto-refine button to improve task description using AI
- Auto-start option to immediately begin AI execution

## Task Card Features

### Display
- Task title
- Visual indicators: in-progress spinner, error state, agent status
- Subtask progress (if subtasks exist)

### Interactions
- Click to open task details panel
- Drag to move between columns or reorder within column
- Right-click context menu (future)

## Real-Time Updates

- Tasks update in real-time when changed by AI agents
- Column changes broadcast to all connected clients
- Hook execution status visible on cards
- New tasks appear automatically

## Keyboard Shortcuts

- `Cmd+K`: Quick actions (future)
- `Escape`: Close modals/panels
