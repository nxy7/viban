---
title: REST API
description: Viban REST API reference for programmatic access to tasks and projects.
---

# REST API

Viban exposes a RESTful API for programmatic access. This reference covers all available endpoints.

## Authentication

All API requests require authentication via Bearer token:

```bash
curl -H "Authorization: Bearer $VIBAN_TOKEN" \
  https://api.viban.dev/v1/projects
```

### Obtaining a Token

1. Go to Settings → API Tokens
2. Click "Generate Token"
3. Copy and store securely

## Base URL

```
https://api.viban.dev/v1
```

For self-hosted: `https://your-domain.com/api/v1`

## Projects

### List Projects

```http
GET /projects
```

**Response:**
```json
{
  "data": [
    {
      "id": "proj_abc123",
      "name": "My Project",
      "repository_url": "https://github.com/user/repo",
      "created_at": "2024-01-15T10:30:00Z"
    }
  ]
}
```

### Get Project

```http
GET /projects/:id
```

### Create Project

```http
POST /projects
Content-Type: application/json

{
  "name": "New Project",
  "repository_url": "https://github.com/user/repo"
}
```

## Tasks

### List Tasks

```http
GET /projects/:project_id/tasks
```

**Query Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `status` | string | Filter by status: todo, inprogress, inreview, done |
| `limit` | integer | Max results (default: 50) |
| `offset` | integer | Pagination offset |

**Response:**
```json
{
  "data": [
    {
      "id": "task_xyz789",
      "title": "Add authentication",
      "description": "Implement user login...",
      "status": "todo",
      "created_at": "2024-01-15T10:30:00Z",
      "updated_at": "2024-01-15T10:30:00Z"
    }
  ],
  "meta": {
    "total": 25,
    "limit": 50,
    "offset": 0
  }
}
```

### Get Task

```http
GET /tasks/:id
```

### Create Task

```http
POST /projects/:project_id/tasks
Content-Type: application/json

{
  "title": "Add dark mode",
  "description": "Implement theme switching..."
}
```

### Update Task

```http
PATCH /tasks/:id
Content-Type: application/json

{
  "title": "Updated title",
  "description": "Updated description",
  "status": "inprogress"
}
```

### Delete Task

```http
DELETE /tasks/:id
```

### Refine Task

```http
POST /tasks/:id/refine
```

Returns the refined description:

```json
{
  "data": {
    "refined_description": "## Objective\n..."
  }
}
```

## Executions

### Get Task Executions

```http
GET /tasks/:id/executions
```

**Response:**
```json
{
  "data": [
    {
      "id": "exec_abc123",
      "task_id": "task_xyz789",
      "status": "running",
      "agent": "claude_code",
      "started_at": "2024-01-15T10:30:00Z",
      "completed_at": null,
      "worktree_path": "/path/to/worktree"
    }
  ]
}
```

### Cancel Execution

```http
POST /executions/:id/cancel
```

## Webhooks

### Register Webhook

```http
POST /projects/:project_id/webhooks
Content-Type: application/json

{
  "url": "https://your-server.com/webhook",
  "events": ["task.created", "task.completed"],
  "secret": "your-webhook-secret"
}
```

### Webhook Events

| Event | Payload |
|-------|---------|
| `task.created` | Task object |
| `task.started` | Task + Execution |
| `task.completed` | Task + Execution |
| `task.failed` | Task + Error |

## Error Handling

### Error Response Format

```json
{
  "error": {
    "code": "not_found",
    "message": "Task not found",
    "details": {}
  }
}
```

### Error Codes

| Code | HTTP Status | Description |
|------|-------------|-------------|
| `unauthorized` | 401 | Invalid or missing token |
| `forbidden` | 403 | Insufficient permissions |
| `not_found` | 404 | Resource not found |
| `validation_error` | 422 | Invalid request data |
| `rate_limited` | 429 | Too many requests |

## Rate Limiting

Default limits:
- 1000 requests per minute
- 10000 requests per hour

Headers included in response:
```
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 999
X-RateLimit-Reset: 1705320000
```
