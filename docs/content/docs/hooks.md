---
title: Hooks System
description: Automate your workflow with Viban's powerful column hooks system.
---

# Hooks System

Viban uses a column-based hook system that automates your workflow. When tasks enter columns, hooks are executed in sequence, enabling powerful automation pipelines.

## Mental Model

Think of hooks as **actions attached to columns**. When a task enters a column, its hooks run. This creates a simple yet powerful model:

```
Task moves to column → Hooks run in sequence
```

## Hook Kinds

Viban supports three kinds of hooks:

### Script Hooks

Run shell commands in the task's worktree directory.

```bash
# Example: Run tests
mix test

# Example: Build the project
npm run build
```

### Agent Hooks

Run AI agents with custom prompts. Supported executors:
- `claude_code` (default)
- `gemini_cli`
- `codex`
- `opencode`
- `cursor_agent`

### System Hooks

Built-in hooks that provide core functionality.

## Built-in System Hooks

### Execute AI (`system:execute-ai`)

The primary hook for AI-powered task execution.

- Processes messages from the task's message queue
- Falls back to task title/description if queue is empty
- Starts the AI executor in the task's worktree
- Requires a worktree to be available

### Auto-Refine Task Description (`system:refine-prompt`)

Uses AI to automatically improve the task description with:
- Success criteria
- Clear requirements
- Proper markdown formatting

Skips tasks that already have detailed descriptions (>500 characters).

### Play Sound (`system:play-sound`)

Plays a notification sound in the browser when a task enters the column.

**Settings:**
- `sound`: The sound to play. Options: `ding` (default), `bell`, `chime`, `success`, `notification`

### Move Task (`system:move-task`)

Automatically moves the task to another column.

**Settings:**
- `target_column`: Where to move the task
  - `"next"` (default) - Move to the next column by position
  - Column name (e.g., `"To Review"`) - Move to specific column

This hook is transparent by default (runs even when task is in error state).

## Execute-Once Hooks

Hooks can be marked as "execute once" - they only run the first time a task enters that column. Useful for:
- Initial setup tasks
- One-time notifications
- Preventing duplicate actions on re-entry

Execution is tracked in the task's `executed_hooks` field.

## Transparent Hooks

Hooks can be marked as "transparent":
- Runs even when the task is in an error state
- Doesn't change the task's status
- Useful for cleanup or notification hooks

## Configuring Hooks

### Via UI

1. Click the column settings (gear icon)
2. Go to "Hooks" tab
3. Add/remove/reorder hooks
4. Configure hook-specific settings

### Hook Settings

Each column hook can have:
- **Position**: Order in the execution sequence (ascending)
- **Execute Once**: Only run first time task enters column
- **Transparent**: Run even when task is in error state
- **Removable**: Whether the hook can be removed (some core hooks are non-removable)
- **Hook Settings**: Hook-specific configuration (e.g., sound selection, target column)

## Execution Details

### Script Execution

Script hooks:
1. Write the command to a temporary script file
2. Add a shebang (`#!/bin/bash`) if not present
3. Add `set -e` for fail-fast behavior
4. Execute in the task's worktree directory
5. Capture stdout/stderr
6. Clean up the temp script

### Error Handling

When a hook fails:
- The error is logged
- Subsequent hooks in the sequence **do not run**
- The task's error state is updated
- You can retry by moving the task out and back in

## Custom Database Hooks

Beyond system hooks, you can create custom hooks per board:

### Creating Script Hooks

Script hooks execute shell commands:
- Require a `command` field
- Run in the task's worktree directory
- Support any shell command or script

### Creating Agent Hooks

Agent hooks run AI agents:
- Require an `agent_prompt` field
- Specify an `agent_executor` (defaults to `claude_code`)
- Optionally enable `agent_auto_approve` for tool calls

## Best Practices

### Column Design

Design your columns around your workflow stages. Hooks run in sequence, so you can chain them to create automation pipelines:

```
[Todo]
  ├─ Auto-Refine (improve task description)
  └─ Move Task → In Progress

[In Progress]
  ├─ Execute AI (run the agent)
  └─ Move Task → To Review

[To Review]
  └─ Play Sound (notify of completion)

[Done]
  └─ Script: Send Slack notification
```

This creates a fully automated pipeline: drop a task in Todo, and it gets refined, executed by AI, lands in To Review with a notification sound, and sends a Slack message when marked done.

### Hook Ordering

Order hooks from fastest/most-likely-to-fail first:
1. Quick validation checks
2. Longer-running operations
3. Notifications (usually last)

### Idempotent Hooks

Design hooks to be idempotent when possible - running them multiple times should be safe. Use "execute once" for hooks that shouldn't repeat.
