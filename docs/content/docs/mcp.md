---
title: MCP Server
description: Viban MCP server for AI-to-AI communication and task management.
---

# MCP Server

Viban includes a Model Context Protocol (MCP) server that enables AI-to-AI communication for task management, powered by [AshAi](https://github.com/ash-project/ash_ai).

## Overview

The MCP server allows AI agents like Claude Code to:
- List and manage boards
- Create and update tasks
- Move tasks between columns
- Manage hooks and repositories

This enables scenarios where an AI can autonomously manage its own workload through Viban.

## Endpoint

The MCP server is available at:

```
http://localhost:7771/mcp
```

(In production, use your configured domain and port)

## Claude Code Integration

Add to your Claude Code MCP configuration (`~/.claude/claude_desktop_config.json` or similar):

```json
{
  "mcpServers": {
    "viban": {
      "url": "http://localhost:7771/mcp",
      "transport": "streamable-http"
    }
  }
}
```

## Available Tools

The MCP server exposes tools based on the Ash domain resources:

### Board Tools

#### list_boards
List all kanban boards accessible to the current user.

### Task Tools

#### list_tasks
List tasks with optional filtering by column, status, or priority.

#### create_task
Create a new task in a specified column.

#### update_task
Update a task's title, description, or priority.

#### move_task
Move a task to a different column or reorder within the same column.

#### delete_task
Permanently delete a task and its associated data.

### Column Tools

#### list_columns
List all columns for a specific board, ordered by position.

### Hook Tools

#### list_hooks
List automation hooks configured for a board.

#### create_hook
Create a new automation hook with shell command or AI agent.

### Repository Tools

#### list_repositories
List git repositories associated with boards.

## Usage Examples

### From Claude Code

When Claude Code has the Viban MCP server configured:

```
User: "Check what tasks are in my Viban board and start the next one"

Claude Code:
1. Calls list_boards to find available boards
2. Calls list_tasks to see tasks in each column
3. Uses move_task to move a task to "In Progress"
```

### Self-Managing Workflows

AI can create its own subtasks:

```
User: "Build a user dashboard"

Claude Code:
1. Analyzes requirements
2. Calls create_task for "Create dashboard layout"
3. Calls create_task for "Add user stats component"
4. Calls create_task for "Implement data fetching"
```

## How It Works

Viban uses AshAi's MCP implementation which:

1. Follows the MCP Streamable HTTP Transport specification
2. Uses JSON-RPC for message processing
3. Manages sessions with unique IDs
4. Supports streaming responses

The tools are automatically generated from the Ash domain's tool definitions:

```elixir
# In Viban.Kanban domain
tools do
  tool :list_boards, Viban.Kanban.Board, :read do
    description "List all kanban boards accessible to the current user"
  end

  tool :create_task, Viban.Kanban.Task, :create do
    description "Create a new task in a specified column"
  end
  # ... more tools
end
```

## Troubleshooting

### Connection Issues

Test the MCP endpoint:

```bash
curl http://localhost:7771/mcp
```

### Tool Not Found

Ensure the Viban backend is running and the MCP route is configured. Check `lib/viban_web/router.ex` for the MCP scope.

### Authentication

Currently, the MCP endpoint follows the same authentication as the main API. Ensure proper headers are passed if authentication is required.
