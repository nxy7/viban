---
title: MCP Server
description: Viban MCP server for AI-to-AI communication and task management.
---

# MCP Server

Viban includes a Model Context Protocol (MCP) server that enables AI-to-AI communication for task management.

## Overview

The MCP server allows AI agents like Claude Code to:
- List and manage projects
- Create and update tasks
- Start task execution
- Query task status

This enables scenarios where an AI can autonomously manage its own workload through Viban.

## Configuration

### Enabling MCP Server

The MCP server runs alongside the main Viban backend:

```elixir
# config/config.exs
config :viban, :mcp,
  enabled: true,
  port: 4001
```

### Claude Code Integration

Add to your Claude Code MCP configuration:

```json
{
  "mcpServers": {
    "vibe_kanban": {
      "command": "npx",
      "args": ["-y", "viban-mcp"],
      "env": {
        "VIBAN_API_URL": "http://localhost:4000",
        "VIBAN_API_TOKEN": "your-token"
      }
    }
  }
}
```

## Available Tools

### list_projects

List all available projects.

```typescript
// Returns
{
  projects: [
    { id: "proj_abc", name: "My Project" }
  ]
}
```

### list_tasks

List tasks in a project with optional filtering.

```typescript
// Parameters
{
  project_id: "proj_abc",     // Required
  status?: "todo",            // Optional filter
  limit?: 50                  // Optional limit
}

// Returns
{
  tasks: [
    {
      id: "task_xyz",
      title: "Add auth",
      status: "todo"
    }
  ]
}
```

### get_task

Get detailed task information.

```typescript
// Parameters
{
  task_id: "task_xyz"
}

// Returns
{
  id: "task_xyz",
  title: "Add authentication",
  description: "Full description...",
  status: "todo",
  created_at: "2024-01-15T10:30:00Z"
}
```

### create_task

Create a new task.

```typescript
// Parameters
{
  project_id: "proj_abc",
  title: "New feature",
  description?: "Optional description"
}

// Returns
{
  id: "task_new123",
  title: "New feature",
  status: "todo"
}
```

### update_task

Update an existing task.

```typescript
// Parameters
{
  task_id: "task_xyz",
  title?: "Updated title",
  description?: "Updated description",
  status?: "inprogress"
}
```

### delete_task

Delete a task.

```typescript
// Parameters
{
  task_id: "task_xyz"
}
```

### start_workspace_session

Start working on a task (creates worktree and launches agent).

```typescript
// Parameters
{
  task_id: "task_xyz",
  executor: "CLAUDE_CODE",  // or "CODEX", "GEMINI"
  repos: [
    {
      repo_id: "repo_abc",
      base_branch: "main"
    }
  ]
}
```

### list_repos

List repositories for a project.

```typescript
// Parameters
{
  project_id: "proj_abc"
}

// Returns
{
  repos: [
    {
      id: "repo_abc",
      name: "my-repo",
      url: "https://github.com/user/repo"
    }
  ]
}
```

## Usage Examples

### From Claude Code

When Claude Code has the Viban MCP server configured, it can:

```
User: "Check what tasks are in my Viban project and start working on the highest priority one"

Claude Code:
1. Calls list_projects to find projects
2. Calls list_tasks to see todo items
3. Calls start_workspace_session to begin work
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
5. Starts working on first task
```

## Security

### Authentication

All MCP calls require valid authentication:

```typescript
// Passed via environment
VIBAN_API_TOKEN=your-secure-token
```

### Permissions

MCP operations respect the same permissions as the REST API:
- Users can only access their projects
- Project members have appropriate access levels

### Rate Limiting

MCP calls count toward API rate limits:
- 1000 requests/minute default
- Configurable per token

## Troubleshooting

### Connection Issues

```bash
# Test MCP server connectivity
curl http://localhost:4001/health
```

### Authentication Errors

Verify your token:

```bash
curl -H "Authorization: Bearer $VIBAN_API_TOKEN" \
  http://localhost:4000/api/v1/projects
```

### Tool Not Found

Ensure the MCP server is properly configured in Claude Code's settings and restart Claude Code after changes.
