---
title: AI Agents
description: Learn about AI agents supported by Viban for autonomous task execution.
---

# AI Agents

Viban supports multiple AI agents for autonomous task execution. Learn how each agent works and when to use them.

## Supported Agents

### Claude Code

Claude Code is Anthropic's autonomous coding agent, designed specifically for software development tasks.

**Strengths:**
- Excellent code understanding and generation
- Strong reasoning capabilities
- Built-in tool use (file editing, terminal, etc.)
- Long context windows

**Best For:**
- Complex feature implementation
- Refactoring and code cleanup
- Bug fixing with context
- Documentation generation

**Configuration:**
```bash
# Install
npm install -g @anthropic-ai/claude-code

# Authenticate
claude login
```

### Codex

OpenAI's code generation model, accessible through their API.

**Strengths:**
- Fast code completion
- Good for boilerplate generation
- Multiple language support

**Best For:**
- Quick code generation
- Simple implementations
- Template-based tasks

### Gemini

Google's multimodal AI model with code capabilities.

**Strengths:**
- Multimodal understanding
- Large context window
- Fast inference

**Best For:**
- Tasks involving images/diagrams
- Documentation from mockups
- Multi-file understanding

### Cursor Agent

Cursor's built-in AI agent for code editing.

**Strengths:**
- Tight editor integration
- Good for incremental changes
- Fast iteration

**Best For:**
- Small changes
- Interactive development
- Editor-based workflows

## Agent Selection

When starting a task, you can choose which agent to use:

1. Open task details
2. Select agent from dropdown
3. Drag to "In Progress"

### Automatic Selection

Viban can automatically select the best agent based on:
- Task complexity
- Required capabilities
- Agent availability

## Execution Model

### Isolated Environments

Each task runs in an isolated git worktree:

```
/workspaces/
  /task-abc123/
    /.git  (worktree reference)
    /src
    /...
```

This ensures:
- No conflicts between parallel tasks
- Clean rollback if needed
- Easy code review

### Real-time Streaming

Output streams to the UI in real-time:

1. AI agent writes to stdout
2. Captured by execution worker
3. Broadcast via Phoenix channels
4. Rendered in task detail view

### Error Handling

If an agent encounters an error:

1. Error is logged to execution history
2. Task remains in "In Progress"
3. You can retry or cancel
4. Worktree is preserved for debugging

## Resource Management

### Concurrent Execution

Configure maximum concurrent tasks:

```elixir
# config/config.exs
config :viban, :execution,
  max_concurrent_tasks: 3
```

### Timeouts

Default timeout is 30 minutes. Configure per-task:

```elixir
config :viban, :execution,
  default_timeout: :timer.minutes(30)
```

## Monitoring

### Execution Logs

View detailed logs in the task detail panel:
- Command executed
- Start/end timestamps
- Exit codes
- Output history

### Metrics

Track agent performance:
- Success rate
- Average completion time
- Token usage (where applicable)
