---
title: API Reference
description: Viban API reference for programmatic access to boards and tasks.
---

# API Reference

Viban exposes REST APIs for programmatic access, with real-time updates via Phoenix LiveView.

## Base URL

Development: `http://localhost:7777/api`

For production, use your configured domain.

## Authentication

Most API requests require authentication via session cookies (set during OAuth login).

For programmatic access:
1. Use the test login endpoint (if enabled)
2. Or integrate with the OAuth flow

## REST Endpoints

### Health Check

```http
GET /api/health
```

Returns server health status.

### Hooks

```http
GET /api/boards/:board_id/hooks
```

List all hooks (system + custom) for a board.

```http
GET /api/hooks/system
```

List all available system hooks.

### VCS Integration

```http
GET /api/vcs/repos
```

List repositories from connected VCS provider.

```http
GET /api/vcs/repos/:owner/:repo/branches
```

List branches for a repository.

### Pull Requests

```http
GET /api/vcs/repos/:owner/:repo/pulls
```

List pull requests.

```http
POST /api/vcs/repos/:owner/:repo/pulls
```

Create a new pull request.

### Task Images

```http
GET /api/tasks/:task_id/images/:image_id
```

Retrieve an image attached to a task.

## Real-time Updates

Real-time data synchronization is handled via Phoenix LiveView and PubSub. The frontend receives updates automatically through LiveView's WebSocket connection.

## MCP Server

Viban exposes an MCP (Model Context Protocol) server for AI agent integration at `/mcp`. See the [MCP documentation](/docs/mcp) for details.

## Error Handling

### Error Response Format

```json
{
  "errors": [
    {
      "message": "Error description",
      "field": "optional_field_name"
    }
  ]
}
```

### Common Errors

| Status | Description |
|--------|-------------|
| 401 | Not authenticated |
| 403 | Permission denied |
| 404 | Resource not found |
| 422 | Validation error |
| 500 | Server error |
