---
title: Hooks System
description: Automate your workflow with Viban's powerful column hooks system.
---

# Hooks System

Viban uses a column-based hook system that automates your workflow. When tasks enter or leave columns, hooks are executed in sequence, enabling powerful automation pipelines.

## Mental Model

Think of hooks as **actions attached to columns**. When a task enters a column, its hooks run. This creates a simple yet powerful model:

```
Task moves to column → onEntry hooks run → persistent hooks start
Task leaves column → persistent hooks cleanup
```

## Hook Types

### onEntry Hooks

Run once when a task enters a column. Use for:
- Running tests before review
- Linting code
- Sending notifications
- Refining task descriptions with AI

```
[Backlog] → [In Progress] → [To Review] → [Done]
              ↑                 ↑
              │                 │
              onEntry:         onEntry:
              - create branch  - run tests
              - refine prompt  - lint code
```

### Persistent Hooks

Run continuously while a task is in a column. Use for:
- AI agent execution
- Long-running processes
- Watching for changes

When the task leaves the column, persistent hooks **cleanup** gracefully.

## Execution Order

When a task enters a column:

1. **onEntry hooks** execute sequentially (in defined order)
2. **Persistent hooks** start (in defined order)

When a task leaves a column:

1. **Persistent hooks cleanup** (reverse order)

```
Task enters "In Progress":
  1. [onEntry] Create git branch
  2. [onEntry] Refine task with AI
  3. [Persistent] Start AI agent ← runs until task leaves

Task leaves "In Progress":
  1. [Cleanup] Stop AI agent gracefully
```

## Execute-Once Hooks

Hooks can be marked as "execute once" - they only run the first time a task enters that column. Useful for:
- Creating branches (don't recreate on re-entry)
- Initial setup tasks
- One-time notifications

## Built-in System Hooks

### Create Branch
Creates a git worktree and branch for isolated development.
- Type: onEntry
- Recommended: execute-once

### Refine Prompt
Uses AI to refine the task description with implementation details.
- Type: onEntry
- Recommended: execute-once

### Run Tests
Runs your test suite in the task's worktree.
- Type: onEntry
- Works with: Elixir, JavaScript, Python

### Lint Code
Runs linting/formatting checks.
- Type: onEntry
- Works with: Various languages

### Shell Command
Runs a custom shell command.
- Type: onEntry
- Configurable command and environment

## The AI Executor (Special Persistent Hook)

The "In Progress" column has a special persistent hook that:

1. **Processes pending messages** - Sends queued chat messages to the AI agent
2. **Executes AI tasks** - The agent works on the task
3. **Auto-moves on completion** - When done, moves task to "To Review"

This is implemented as a persistent hook, making the entire system composable.

### Message Queue Behavior

When the AI agent is running:
- New messages are **queued** (status: pending)
- Agent processes messages in order
- When all messages are processed and agent is idle, task moves to review

If you move a task out of "In Progress":
- The AI agent **stops gracefully**
- The task can be moved back to resume work
- Pending messages are preserved

## Configuring Hooks

### Via UI

1. Click the column settings (gear icon)
2. Go to "Hooks" tab
3. Add/remove/reorder hooks
4. Configure hook-specific settings

### Hook Settings

Each hook can have:
- **Position**: Order in the execution sequence
- **Execute Once**: Only run first time task enters column
- **Configuration**: Hook-specific settings (command, timeout, etc.)

## Custom Shell Hooks

Create custom automation with shell commands:

```yaml
Name: Deploy Preview
Command: ./scripts/deploy-preview.sh
Timeout: 300  # seconds
Environment:
  DEPLOY_ENV: preview
  BRANCH: $BRANCH_NAME
```

### Available Variables

| Variable | Description |
|----------|-------------|
| `$TASK_ID` | Unique task identifier |
| `$TASK_TITLE` | Task title |
| `$WORKTREE_PATH` | Path to git worktree |
| `$BRANCH_NAME` | Git branch name |
| `$BOARD_ID` | Board identifier |

## Error Handling

When a hook fails:
- The error is displayed on the task card
- Subsequent hooks in the sequence **do not run**
- The task remains in its current column
- You can retry by moving the task out and back in

## Best Practices

### Column Design

Design your columns around your workflow stages:

```
[Backlog]
  └─ No hooks (just planning)

[Ready]
  └─ onEntry: Create branch (execute-once)
  └─ onEntry: Refine prompt (execute-once)

[In Progress]
  └─ Persistent: AI Executor

[To Review]
  └─ onEntry: Run tests
  └─ onEntry: Lint code

[Done]
  └─ onEntry: Notify team (optional)
```

### Hook Ordering

Order hooks from fastest/most-likely-to-fail first:
1. Quick validation checks
2. Longer-running operations
3. Notifications (usually last)

### Idempotent Hooks

Design hooks to be idempotent when possible - running them multiple times should be safe.
