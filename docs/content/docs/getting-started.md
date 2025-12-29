---
title: Quick Start
description: Get started with Viban - set up your first AI-powered Kanban board in minutes.
---

# Quick Start

Get up and running with Viban in minutes. This guide will walk you through setting up your first AI-powered Kanban board.

## Prerequisites

Before you begin, ensure you have:

- **Elixir 1.15+** and **Erlang/OTP 26+**
- **Node.js 20+** and **Bun** (or npm)
- **PostgreSQL 15+**
- **Claude Code CLI** installed and authenticated

## Installation

### 1. Clone the Repository

```bash
git clone https://github.com/nxy7/viban.git
cd viban
```

### 2. Set Up the Backend

```bash
cd backend
mix deps.get
mix ecto.setup
```

### 3. Set Up the Frontend

```bash
cd frontend
bun install
```

### 4. Start the Development Servers

```bash
# In the root directory
just dev
```

This will start:
- Backend server at `http://localhost:4000`
- Frontend at `http://localhost:3000`
- Electric SQL sync service

## Creating Your First Project

1. Open the Viban dashboard at `http://localhost:3000`
2. Click "New Project" and give it a name
3. Connect your GitHub repository (optional but recommended)

## Creating Your First Task

1. Click "Add Task" in the Todo column
2. Write a description of what you want to build
3. Click the "Refine" button to enhance your task description
4. Review the refined prompt and adjust if needed

## Running Your First AI Task

1. Drag your task from "Todo" to "In Progress"
2. Watch as Viban:
   - Creates an isolated git worktree
   - Launches Claude Code
   - Streams real-time output
3. Once complete, the task moves to "In Review"
4. Review the changes and merge when ready

## Next Steps

- Learn about [Boards & Tasks](/docs/boards-and-tasks)
- Understand [AI Agents](/docs/ai-agents) and how they work
- Set up [Custom Hooks](/docs/custom-hooks) for automation
