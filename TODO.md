# Viban: LiveView to Hologram Migration Plan

This document tracks the complete migration from Phoenix LiveView to Hologram, including all missing features from the original SolidJS frontend.

**Goal:** Full-featured Kanban application with AI integration, entirely in Elixir (transpiled to JS for frontend).

**Key Challenge:** Hologram doesn't have PubSub/server-initiated updates yet. We'll use a hybrid approach with Phoenix Channels for real-time features until Hologram's PubSub is ready.

---

## Phase 0: Infrastructure Setup

### 0.1 Install and Configure Hologram
- [ ] Add `{:hologram, "~> 0.6.6"}` to mix.exs dependencies
- [ ] Add `:hologram` to compilers in mix.exs project config
- [ ] Configure Hologram.Router plug in endpoint.ex (before Phoenix router)
- [ ] Update Plug.Static to serve Hologram assets
- [ ] Add `:hologram` to .formatter.exs import_deps
- [ ] Add `/priv/static/hologram/` to .gitignore
- [ ] Run `mix deps.get` and verify compilation

### 0.2 Create Directory Structure
- [ ] Create `lib/viban_web/hologram/` directory
- [ ] Create `lib/viban_web/hologram/pages/` for page modules
- [ ] Create `lib/viban_web/hologram/components/` for reusable components
- [ ] Create `lib/viban_web/hologram/layouts/` for layout modules

### 0.3 Create Main Layout
- [ ] Create `MainLayout` with dark theme styling
- [ ] Include `Hologram.UI.Runtime` component in head
- [ ] Add Tailwind CSS (via CDN or compiled)
- [ ] Add Inter font and base styles
- [ ] Add slot for page content
- [ ] Add flash message display

### 0.4 Setup Real-Time Communication (Hybrid Approach)
- [ ] Create dedicated Phoenix Channel for Hologram pages (`HologramChannel`)
- [ ] Create JS hook to connect Hologram pages to Phoenix Channel
- [ ] Define message types for real-time updates:
  - `task_created`, `task_updated`, `task_deleted`, `task_moved`
  - `executor_message`, `executor_status_changed`
  - `hook_execution_update`
  - `subtasks_generated`
- [ ] Create helper module for broadcasting from Ash resources

---

## Phase 1: Home Page

### 1.1 Basic Home Page
- [ ] Create `HomePage` module with route `/`
- [ ] Implement init/3 to load user from session and boards list
- [ ] Create basic template with header, board list, and footer

### 1.2 User Authentication UI
- [ ] Create `UserMenu` component (avatar, name, logout button)
- [ ] Create `GitHubLoginButton` component
- [ ] Create `DeviceFlowModal` component for GitHub device flow
- [ ] Implement device flow polling via command
- [ ] Add "Click to copy" functionality for user code
- [ ] Handle authentication success/redirect

### 1.3 Board List
- [ ] Create `BoardCard` component
- [ ] Display boards as grid with title, description, updated date
- [ ] Empty state when no boards exist
- [ ] Navigation to board page on click

### 1.4 Create Board Form
- [ ] Create `CreateBoardForm` component
- [ ] Repository search and selection
- [ ] Auto-fill board name from repo using `BoardNameGenerator`
- [ ] Form validation
- [ ] Submit handling via command
- [ ] Error display

---

## Phase 2: Board Page - Core

### 2.1 Basic Board Page
- [ ] Create `BoardPage` module with route `/board/:board_id`
- [ ] Create `BoardPage` module with route `/board/:board_id/card/:task_id`
- [ ] Load board, columns, tasks in init/3
- [ ] Join Phoenix Channel for real-time updates
- [ ] Setup channel message handlers as actions

### 2.2 Board Header
- [ ] Create `BoardHeader` component
- [ ] Board title display
- [ ] Search/filter input
- [ ] "New Task" button
- [ ] Settings button
- [ ] Back to home navigation

### 2.3 Columns
- [ ] Create `Column` component
- [ ] Column header with name, task count, color indicator
- [ ] Column settings button
- [ ] "Add a card" button at bottom
- [ ] Task list area

### 2.4 Task Cards
- [ ] Create `TaskCard` component
- [ ] Title display (with line clamp)
- [ ] Description preview (markdown rendered)
- [ ] Status indicators:
  - [ ] In progress spinner
  - [ ] Queued badge
  - [ ] Waiting for input badge
  - [ ] Error badge
- [ ] PR badge (with status color)
- [ ] Parent/subtask indicators
- [ ] Click to open task details

### 2.5 Drag and Drop (NEW - was missing)
- [ ] Implement drag and drop using pointer events
- [ ] Create `DraggableTaskCard` wrapper component
- [ ] Create `DropZone` component for columns
- [ ] Visual feedback during drag (ghost card, drop indicators)
- [ ] Handle drop to move task via command
- [ ] Support reordering within same column
- [ ] Support moving between columns

---

## Phase 3: Create Task Modal

### 3.1 Basic Create Task Modal
- [ ] Create `CreateTaskModal` component
- [ ] Title input (required)
- [ ] Description textarea
- [ ] Column indicator in header
- [ ] Cancel and Create buttons
- [ ] Form validation

### 3.2 Template Selection
- [ ] Load templates when modal opens
- [ ] Template dropdown selector
- [ ] Auto-fill description from template

### 3.3 Refine with AI
- [ ] "Refine with AI" button
- [ ] Loading state during refinement
- [ ] Update description with refined text
- [ ] Error handling

### 3.4 Autostart Checkbox
- [ ] "Start immediately" checkbox
- [ ] Only show if "In Progress" column exists
- [ ] Move task to In Progress after creation

### 3.5 Custom Branch Name (NEW - was missing)
- [ ] Add "Worktree Name" input field
- [ ] Auto-generate from title
- [ ] Track manual edits to prevent auto-update
- [ ] Validation for branch name format

### 3.6 Draft Persistence (NEW - was missing)
- [ ] Save title/description to localStorage on change
- [ ] Restore draft when modal opens
- [ ] Clear draft on successful creation

---

## Phase 4: Task Details Panel

### 4.1 Basic Panel Structure
- [ ] Create `TaskDetailsPanel` component
- [ ] Slide-in panel from right
- [ ] Fullscreen toggle (f key)
- [ ] Close button (Escape key)
- [ ] Two-column layout (activity feed + details sidebar)

### 4.2 Panel Header
- [ ] Task title (editable inline)
- [ ] Agent status badge
- [ ] Worktree actions (open in editor, open folder)
- [ ] Fullscreen toggle button
- [ ] Hide details toggle button
- [ ] Close button

### 4.3 Activity Feed
- [ ] Scrollable activity list
- [ ] Task created entry
- [ ] User messages (styled differently)
- [ ] AI assistant messages (with markdown)
- [ ] Hook execution entries (grouped)
- [ ] Session start/end dividers
- [ ] Auto-scroll to bottom on new messages

### 4.4 Chat Input
- [ ] Textarea for message input
- [ ] Executor selector dropdown
- [ ] Send button
- [ ] Enter to send (Shift+Enter for newline)
- [ ] Disabled state when sending

### 4.5 Image Paste Support (NEW - was missing)
- [ ] Paste image handler for chat input
- [ ] Image preview thumbnails
- [ ] Remove image button
- [ ] Send images with message
- [ ] Store images as base64

### 4.6 Details Sidebar
- [ ] Title field (editable)
- [ ] Column selector dropdown
- [ ] Description field (editable)
- [ ] Branch display with copy button
- [ ] PR link with status badge
- [ ] Subtasks list
- [ ] Error display with dismiss
- [ ] Actions grid (Branch, Create PR, Duplicate, Delete)
- [ ] Recent hooks list

### 4.7 Refine Description (NEW - was missing)
- [ ] "Refine with AI" button in description section
- [ ] Update description with refined text

### 4.8 Image Paste in Description (NEW - was missing)
- [ ] Paste image handler for description textarea
- [ ] Image preview and management
- [ ] Save images with task

---

## Phase 5: LLM Todo List (NEW - was missing)

### 5.1 Agent Progress Panel
- [ ] Create `LLMTodoList` component
- [ ] Header with "Agent Progress" and count (X/Y)
- [ ] Progress bar (percentage complete)
- [ ] Current task indicator (pulsing dot + text)
- [ ] Todo list with status icons:
  - [ ] Checkbox for pending
  - [ ] Spinner for in_progress
  - [ ] Checkmark for completed
- [ ] Strikethrough for completed items
- [ ] Scrollable if list is long

### 5.2 Compact Card Progress (NEW - was missing)
- [ ] Create `LLMTodoProgress` component for task cards
- [ ] Mini progress bar
- [ ] Compact count display
- [ ] Current task hint text
- [ ] Only show when task is running

### 5.3 Real-Time Todo Updates
- [ ] Receive todo updates via Phoenix Channel
- [ ] Update progress bar and counts
- [ ] Animate current task changes

---

## Phase 6: Create PR Modal

### 6.1 Basic PR Modal
- [ ] Create `CreatePRModal` component
- [ ] Title input (pre-filled from task)
- [ ] Body textarea (pre-filled from description)
- [ ] Cancel and Create buttons

### 6.2 Branch Selector (NEW - was missing)
- [ ] Load branches from repository via command
- [ ] Branch dropdown with default branch marked
- [ ] Show loading state while fetching
- [ ] Remember preferred base branch in localStorage

### 6.3 PR Creation
- [ ] Submit PR creation via command
- [ ] Show loading state
- [ ] Handle success (close modal, update task)
- [ ] Handle errors

---

## Phase 7: Board Settings Panel

### 7.1 Settings Panel Structure
- [ ] Slide-in panel from right
- [ ] Tab navigation (General, Templates, Hooks, Periodical Tasks, Tools)
- [ ] Close button

### 7.2 General Tab
- [ ] Board name (display only)
- [ ] Repository configuration
- [ ] Edit repository button
- [ ] Repository form (provider, URL, branch)

### 7.3 Templates Tab
- [ ] List of templates with edit/delete buttons
- [ ] "Add Template" button
- [ ] Template form (name, description template)
- [ ] Save/cancel buttons

### 7.4 Hooks Tab
- [ ] List of hooks with edit/delete buttons
- [ ] "Add Hook" button
- [ ] Hook kind selector (Script, System Hook)
- [ ] Script hook form (name, script, timeout)
- [ ] System hook form (name, type, config)
- [ ] Save/cancel buttons

### 7.5 Sound Preview (NEW - was missing)
- [ ] Sound selector dropdown for Play Sound hook
- [ ] Preview button to play selected sound
- [ ] Stop button while playing

### 7.6 Periodical Tasks Tab
- [ ] List of periodical tasks with toggle/edit/delete
- [ ] "Add Periodical Task" button
- [ ] Form (name, cron expression, prompt, executor)
- [ ] Cron presets dropdown
- [ ] Save/cancel buttons

### 7.7 Tools Tab
- [ ] List of available system tools
- [ ] Tool descriptions
- [ ] Enable/disable toggles (if applicable)

---

## Phase 8: Column Settings Popup

### 8.1 Basic Popup
- [ ] Create `ColumnSettingsPopup` component
- [ ] Positioned near column header
- [ ] Tab navigation (General, Hooks, Danger)
- [ ] Close on click outside

### 8.2 General Tab
- [ ] Column name input
- [ ] Color selector (predefined colors)
- [ ] Concurrency limit toggle and input

### 8.3 Hooks Tab
- [ ] List of column hooks with toggle/remove
- [ ] Hook selector to add new hook
- [ ] Execute once toggle
- [ ] Transparent mode toggle

### 8.4 Danger Tab
- [ ] "Delete all tasks" button
- [ ] Confirmation dialog

---

## Phase 9: Keyboard Shortcuts

### 9.1 Global Shortcuts
- [ ] `n` - Open create task modal (TODO column)
- [ ] `/` - Focus search input
- [ ] `,` - Open settings
- [ ] `Shift + ?` - Show shortcuts help

### 9.2 Task Panel Shortcuts
- [ ] `Escape` - Close panel/modal
- [ ] `f` - Toggle fullscreen
- [ ] `Ctrl+H` - Toggle details sidebar
- [ ] `Ctrl+D` - Duplicate task
- [ ] `Ctrl+E` - Open in explorer (if worktree exists)
- [ ] `Ctrl+C` - Open in code editor (if worktree exists)
- [ ] `Ctrl+P` - Open/Create PR
- [ ] `Backspace` - Delete task (with confirmation)
- [ ] `Left/Right` - Navigate between tasks

### 9.3 Shortcuts Help Modal
- [ ] Create `ShortcutsHelpModal` component
- [ ] List all shortcuts with descriptions
- [ ] Close on Escape or click outside

---

## Phase 10: Parent/Child Task Highlighting (NEW - was missing)

### 10.1 Task Relationship Context
- [ ] Create context for tracking hovered task
- [ ] Track parent/child relationships

### 10.2 Glow Effects
- [ ] Parent task glows when hovering child
- [ ] Child tasks glow when hovering parent
- [ ] Different glow colors for parent vs child
- [ ] Smooth glow animation

### 10.3 Visual Indicators
- [ ] Parent task icon on cards
- [ ] Subtask icon on cards
- [ ] Click on subtask to navigate to parent

---

## Phase 11: Real-Time Features Integration

### 11.1 Phoenix Channel Integration
- [ ] Connect to channel on page mount
- [ ] Handle reconnection
- [ ] Broadcast task CRUD operations
- [ ] Broadcast executor messages

### 11.2 Task Updates
- [ ] Receive and apply task_created
- [ ] Receive and apply task_updated
- [ ] Receive and apply task_deleted
- [ ] Receive and apply task_moved
- [ ] Update UI without full refresh

### 11.3 Executor Updates
- [ ] Receive executor session start/end
- [ ] Receive chat messages (user and assistant)
- [ ] Receive agent status changes
- [ ] Receive LLM todos updates
- [ ] Update activity feed in real-time

### 11.4 Hook Execution Updates
- [ ] Receive hook execution status changes
- [ ] Update hook badges on tasks
- [ ] Update activity feed

### 11.5 Sound Notifications
- [ ] Receive play_sound events
- [ ] Play appropriate sound
- [ ] Respect browser audio permissions

---

## Phase 12: Testing

### 12.1 Unit Tests
- [ ] Test Hologram components render correctly
- [ ] Test action handlers update state correctly
- [ ] Test command handlers return correct actions

### 12.2 Integration Tests
- [ ] Test page navigation
- [ ] Test form submissions
- [ ] Test real-time updates via channel

### 12.3 E2E Tests (Optional)
- [ ] Setup Playwright or similar
- [ ] Test critical user flows
- [ ] Test drag and drop
- [ ] Test keyboard shortcuts

---

## Phase 13: Cleanup and Polish

### 13.1 Remove LiveView Code
- [ ] Remove LiveView page modules
- [ ] Remove LiveView components
- [ ] Remove LiveView-specific hooks
- [ ] Update router to only use Hologram

### 13.2 Performance Optimization
- [ ] Minimize re-renders
- [ ] Optimize large lists (virtual scrolling if needed)
- [ ] Lazy load heavy components

### 13.3 Error Handling
- [ ] Add error boundaries
- [ ] Handle network errors gracefully
- [ ] Add retry logic for failed commands

### 13.4 Accessibility
- [ ] Add ARIA labels
- [ ] Ensure keyboard navigation works
- [ ] Test with screen reader

---

## Feature Checklist Summary

### From Original SolidJS (currently missing in LiveView):
- [ ] Drag and drop tasks between columns
- [ ] LLM Todo List with progress bar
- [ ] LLM Todo Progress on task cards
- [ ] Image paste support in chat
- [ ] Image paste support in description
- [ ] Custom branch name in create task modal
- [ ] Draft persistence (localStorage)
- [ ] Branch selector in create PR modal
- [ ] Preferred base branch persistence
- [ ] Refine description for existing tasks
- [ ] Full keyboard shortcuts in task panel
- [ ] Sound preview in hook settings
- [ ] Parent/child task glow highlighting

### Currently Working in LiveView (must port):
- [x] Home page with board list
- [x] GitHub device flow authentication
- [x] Create board form with repo selection
- [x] Board page with columns and tasks
- [x] Task cards with status badges
- [x] Create task modal (basic)
- [x] Task templates
- [x] Refine with AI in create modal
- [x] Autostart checkbox
- [x] Task details panel
- [x] Activity feed
- [x] Chat with AI
- [x] Executor selector
- [x] Details sidebar
- [x] Subtasks list
- [x] Generate subtasks
- [x] Create worktree
- [x] Create PR
- [x] Board settings
- [x] Column settings
- [x] Basic keyboard shortcuts

---

## Notes

### Hologram Limitations to Watch
1. **No PubSub yet** - Using Phoenix Channels as bridge
2. **~74% stdlib coverage** - May hit unsupported functions
3. **No file upload** - Image handling via base64/paste only
4. **No drag-drop primitives** - Must implement with pointer events

### Migration Strategy
1. Keep LiveView running during migration
2. Build Hologram pages alongside
3. Switch routes incrementally
4. Remove LiveView code after full migration

### Resources
- [Hologram Docs](https://hologram.page/docs/introduction)
- [Hologram GitHub](https://github.com/bartblast/hologram)
- [Hologram Forum](https://elixirforum.com/c/elixir-framework-forums/hologram-forum/122)
