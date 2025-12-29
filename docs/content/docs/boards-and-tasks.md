---
title: Boards & Tasks
description: Learn how to organize your work with Viban's Kanban system.
---

# Boards & Tasks

Learn how to organize your work with Viban's Kanban system.

## Understanding Boards

A board in Viban represents a project or workspace. Each board contains:

- **Columns**: Visual lanes for different task states
- **Tasks**: Individual work items that move through columns
- **Repository**: Connected Git repository for code changes

### Default Columns

Every board comes with four default columns:

| Column | Purpose |
|--------|---------|
| **Todo** | Tasks waiting to be started |
| **In Progress** | Tasks currently being worked on by AI |
| **In Review** | Completed tasks awaiting review |
| **Done** | Finished and merged tasks |

## Working with Tasks

### Creating Tasks

1. Click "Add Task" in the Todo column
2. Enter a title (required)
3. Add a description (optional but recommended)
4. Save the task

### Task Descriptions

Write clear, actionable descriptions for best AI results:

**Good Example:**
```
Add user authentication with email/password login.

Requirements:
- Registration form with email validation
- Login form with remember me option
- Password reset via email
- Session management with JWT tokens
```

**Poor Example:**
```
Add login
```

### Refining Tasks

Use the "Refine" button to automatically enhance task descriptions:

1. Create a task with a basic description
2. Click the "Refine" button
3. AI transforms it into a detailed prompt with:
   - Clear objectives
   - Acceptance criteria
   - Scope boundaries
   - Implementation suggestions

### Task Position

Tasks don't have explicit status fields - their status is determined by which column they belong to. Moving a task between columns changes its effective state. Tasks also have an `agent_status` that tracks AI execution state:

| Agent Status | Description |
|-------------|-------------|
| `idle` | No AI activity |
| `thinking` | AI is processing |
| `executing` | AI is running commands |
| `error` | An error occurred |

## Moving Tasks

### Drag and Drop

Simply drag a task card to move it between columns. When you drag to "In Progress":

1. Viban creates a git worktree
2. Launches the AI agent
3. Starts streaming output

### Automatic Transitions

- **In Progress → In Review**: When AI completes work
- **In Review → Done**: When you merge the changes

## Task Output

While a task is in progress, you can view:

- **Real-time output**: Live streaming from the AI agent
- **Git changes**: Files modified in the worktree
- **Execution logs**: Detailed execution history

## Best Practices

1. **One feature per task**: Keep tasks focused and atomic
2. **Use refinement**: Let AI enhance your descriptions
3. **Review carefully**: Always review AI-generated code
4. **Test locally**: Run tests before merging
