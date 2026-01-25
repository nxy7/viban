---
title: Introduction
description: Introduction to Viban - AI-powered Kanban for autonomous task execution with Claude Code integration.
---

# Introduction to Viban

Viban is an AI-powered Kanban board that enables autonomous task execution through Claude Code integration. Instead of manually implementing features, you describe what you want, drag the task to "In Progress", and let AI handle the rest.

## What is Viban?

Viban combines the familiar Kanban workflow with cutting-edge AI capabilities:

- **Visual Task Management**: Organize work in columns (Todo, In Progress, In Review, Done)
- **Hooks System**: Configure hooks on columns to automate your workflow - run AI agents, scripts, move tasks, and more
- **Real-time Streaming**: Watch AI work in real-time with live output streaming
- **Git Integration**: Each task gets its own isolated git worktree for clean development

## Key Features

### Autonomous Development
Configure your columns with hooks to create automated pipelines. A typical setup:
1. **Todo**: Auto-Refine hook improves task descriptions, then Move hook sends to In Progress
2. **In Progress**: Execute AI hook runs Claude Code, then Move hook sends to To Review
3. **To Review**: Play Sound hook notifies you the task is ready

Each task gets an isolated git worktree, and you can watch AI work in real-time with live output streaming.

### Task Refinement
Use the "Refine" button on any task to transform a simple description into a high-quality, actionable prompt. The AI will add:
- Clear objectives
- Acceptance criteria
- Scope boundaries
- Implementation guidance

### Keyboard-Centric Navigation
Viban is designed for power users who prefer keyboard navigation. Press `Shift + ?` to view all available shortcuts, or use common keys like `n` for new task, `/` to search, and arrow keys to navigate between tasks. See [Keyboard Shortcuts](/docs/keyboard-shortcuts) for the complete list.

### Periodical Tasks
Automate recurring work with scheduled task execution. Set up tasks that run hourly, daily, weekly, or on custom cron schedules for maintenance, dependency updates, code quality checks, and more. See [Periodical Tasks](/docs/periodical-tasks) for details.

### Multiple AI Agents
Viban supports multiple AI executors:
- **Claude Code**: Anthropic's autonomous coding agent (default)
- **Gemini CLI**: Google's Gemini model for code tasks

## Architecture

Viban is a single Elixir application:

1. **Server**: Elixir/Phoenix with Ash Framework for data management and LiveView for the UI
2. **Database**: SQLite for simple, file-based persistence
3. **AI Workers**: Background processes that execute tasks using AI agents

## Getting Started

Ready to start using Viban? It's as simple as:

```bash
npx @nxy7/viban
```

Head to the [Quick Start](/docs/getting-started) guide for more details.
