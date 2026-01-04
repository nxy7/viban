---
title: Introduction
description: Introduction to Viban - AI-powered Kanban for autonomous task execution with Claude Code integration.
---

# Introduction to Viban

Viban is an AI-powered Kanban board that enables autonomous task execution through Claude Code integration. Instead of manually implementing features, you describe what you want, drag the task to "In Progress", and let AI handle the rest.

## What is Viban?

Viban combines the familiar Kanban workflow with cutting-edge AI capabilities:

- **Visual Task Management**: Organize work in columns (Todo, In Progress, In Review, Done)
- **AI Execution**: Tasks are automatically worked on by Claude Code when moved to "In Progress"
- **Real-time Streaming**: Watch AI work in real-time with live output streaming
- **Git Integration**: Each task gets its own isolated git worktree for clean development

## Key Features

### Autonomous Development
When you drag a task to the "In Progress" column, Viban automatically:
1. Creates an isolated git worktree
2. Launches Claude Code with your task description
3. Streams output in real-time so you can monitor progress
4. Creates a branch ready for review when complete

### Task Refinement
Use the "Refine" button on any task to transform a simple description into a high-quality, actionable prompt. The AI will add:
- Clear objectives
- Acceptance criteria
- Scope boundaries
- Implementation guidance

### Multiple AI Agents
Viban supports multiple AI executors:
- **Claude Code**: Anthropic's autonomous coding agent (default)
- **Gemini CLI**: Google's Gemini model for code tasks
- **Codex**: OpenAI Codex executor
- **OpenCode**: OpenCode agent
- **Cursor Agent**: Cursor AI agent

## Architecture

Viban consists of three main components:

1. **Frontend**: SolidJS application with real-time sync via Electric SQL
2. **Backend**: Elixir/Phoenix server with Ash Framework for data management
3. **AI Workers**: Background processes that execute tasks using AI agents

## Getting Started

Ready to start using Viban? Head to the [Quick Start](/docs/getting-started) guide to set up your first project.
