# Task View (Details Panel)

A slide-out panel that shows task details and allows interaction with AI agents.

## Panel Layout

- **Header**: Task title (editable), close button, action buttons
- **Tabs**: Details, Activity, Settings
- **Chat Interface**: Message input at bottom

## Details Tab

### Task Information
- Title (inline editable)
- Description (markdown editor with preview)
- Branch name display
- Worktree path (if created)
- Current column indicator

### Subtasks
- List of subtasks with checkboxes
- Add new subtask inline
- Reorder subtasks
- Delete subtasks
- Generate subtasks via AI button

### Actions
- Refine task (AI improves title/description)
- Generate subtasks (AI creates breakdown)
- Create PR (opens modal with title, body, base branch)
- Stop execution (cancels running AI agent)
- Clear error (resets error state)

## Activity Tab

### Activity Feed
- Chronological list of task events
- Event types:
  - User messages
  - AI responses
  - Hook executions (with status: completed, failed, skipped)
  - Task movements between columns
  - Error events

### Hook Execution Display
- Hook name
- Status indicator (running, completed, failed, skipped)
- Error message (if failed)
- Skip reason (if skipped)
- Timestamp

## Chat Interface

### Message Input
- Text area for user messages
- `Cmd+Enter` to send
- Image attachment support (paste or upload)
- Executor selector (Claude Code, Gemini CLI)

### Message Flow
1. User sends message
2. Message queued on task
3. Task moves to "In Progress" column
4. Execute AI hook processes message
5. AI response streams to activity feed
6. On completion, Move Task hook triggers
7. Task moves to "To Review" column

## Settings Tab

### Task Settings
- Auto-start toggle
- Custom branch name override

### Danger Zone
- Delete task (with confirmation)

## Real-Time Features

- AI output streams live to activity feed
- Hook execution status updates in real-time
- Task status changes reflect immediately
- Multiple users see same state
