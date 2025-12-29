---
title: Custom Hooks
description: Build powerful automations with custom hooks in Viban.
---

# Custom Hooks

Build powerful automations with custom hooks. This guide covers how to create and configure hooks beyond the built-in system hooks.

## Hook Types

Viban supports two types of custom hooks:

### Script Hooks

Execute shell commands in the task's worktree directory.

**Required fields:**
- `name`: Display name for the hook
- `command`: Shell command to execute

**Example use cases:**
- Run tests before review
- Build the project
- Deploy to preview environments
- Run linting/formatting

### Agent Hooks

Run AI agents with custom prompts for automated code changes.

**Required fields:**
- `name`: Display name for the hook
- `agent_prompt`: System prompt for the AI agent

**Optional fields:**
- `agent_executor`: Which AI to use (`claude_code`, `gemini_cli`, `codex`, `opencode`, `cursor_agent`)
- `agent_auto_approve`: Whether the agent can auto-approve tool calls

## Creating Custom Hooks

### Via the UI

1. Open board settings
2. Navigate to the "Hooks" section
3. Click "Create Hook"
4. Fill in the required fields
5. Save the hook

### Adding Hooks to Columns

1. Click the column settings (gear icon)
2. Go to the "Hooks" tab
3. Click "Add Hook" and select your custom hook
4. Configure position, execute-once, and other settings
5. Save

## Script Hook Examples

### Run Tests

```bash
# Elixir project
mix test

# Node.js project
npm test

# Python project
pytest
```

### Deploy Preview

```bash
#!/bin/bash
set -e

# Build the project
npm run build

# Deploy to preview
vercel deploy --prebuilt
```

### Run Linting

```bash
# Multi-language linting
if [ -f "mix.exs" ]; then
  mix format --check-formatted
elif [ -f "package.json" ]; then
  npm run lint
fi
```

### Security Scanning

```bash
npm audit --audit-level=high
if [ $? -ne 0 ]; then
  echo "Security vulnerabilities found!"
  exit 1
fi
```

## Agent Hook Examples

### Code Review Agent

```
You are a code reviewer. Review all changes in this worktree:

1. Check for common bugs and issues
2. Verify proper error handling
3. Look for security vulnerabilities
4. Suggest improvements

Output a summary of findings as a markdown file.
```

### Documentation Generator

```
Generate documentation for all new or modified files in this worktree.

For each file:
1. Add JSDoc/typedoc comments to functions
2. Update README if needed
3. Add inline comments for complex logic
```

## Hook Configuration

### Default Settings

When creating a hook, you can set defaults that apply when the hook is added to a column:

- `default_execute_once`: Whether the hook should only run once per task (default: false)
- `default_transparent`: Whether the hook should run even when task is in error state (default: false)

### Per-Column Settings

When adding a hook to a column, you can override:

- **Position**: Execution order (hooks run in ascending position order)
- **Execute Once**: Only run first time task enters column
- **Transparent**: Run even when task is in error state
- **Hook Settings**: Hook-specific configuration (varies by hook type)

## Script Execution Details

Script hooks are executed with these behaviors:

1. **Shebang handling**: If your command doesn't start with `#!`, bash is used
2. **Fail-fast**: `set -e` is added automatically for non-shebang scripts
3. **Working directory**: Always the task's worktree
4. **Output capture**: stdout and stderr are captured and logged
5. **Temp files**: Scripts are written to temp files and cleaned up after execution

### Exit Codes

- `0`: Success - hook completes, next hook runs
- Non-zero: Failure - error is logged, subsequent hooks are skipped

## Agent Execution Details

Agent hooks:

1. Build a prompt from `agent_prompt` plus task context
2. Start the specified executor in the worktree
3. Wait for completion
4. Capture output for logging

## Best Practices

### Keep Hooks Focused

Each hook should do one thing well:
- ✅ Run tests
- ✅ Deploy preview
- ❌ Run tests AND deploy AND notify (split into multiple hooks)

### Handle Errors Gracefully

Script hooks should:
- Use `set -e` for fail-fast behavior
- Provide clear error messages
- Return appropriate exit codes

### Make Hooks Idempotent

Running a hook multiple times should be safe:
- Check if work is already done
- Use "execute once" for one-time operations
- Handle partial completion gracefully

### Use Appropriate Timeouts

Long-running hooks can block task processing. Consider:
- Breaking long tasks into smaller hooks
- Using background processes for non-blocking work

### Test Locally First

Before attaching hooks to production columns:

```bash
# Export test variables
export WORKTREE_PATH=/path/to/test/worktree

# Run your hook command manually
./your-hook-script.sh
```
