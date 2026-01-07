---
title: Quick Start
description: Get started with Viban - set up your first AI-powered Kanban board in minutes.
---

# Quick Start

Get up and running with Viban in minutes. This guide will walk you through setting up your first AI-powered Kanban board.

## Prerequisites

| Tool | Required | Installation |
|------|----------|--------------|
| Docker | **Yes** | [Get Docker](https://docs.docker.com/get-docker/) |
| Node.js | For npx install | [Get Node.js](https://nodejs.org/) |

## Install & Run

```bash
npx @nxy7/viban
```

That's it! Viban will:
1. Download the appropriate binary for your platform
2. Start a PostgreSQL container automatically
3. Open your browser to the app

> **Note**: Viban uses HTTPS with a self-signed certificate for HTTP/2 support. Your browser may show a security warning on first visit - this is expected. Click "Advanced" → "Proceed" to continue.

## Alternative: Direct Binary Download

You can also download the binary directly from [GitHub Releases](https://github.com/nxy7/viban/releases):

```bash
# macOS (Apple Silicon)
curl -L https://github.com/nxy7/viban/releases/latest/download/viban-macos_arm -o viban
chmod +x viban
./viban

# Linux (x64)
curl -L https://github.com/nxy7/viban/releases/latest/download/viban-linux_intel -o viban
chmod +x viban
./viban
```

## Creating Your First Project

1. Open the Viban dashboard at `http://localhost:7777`
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
   - Launches Claude Code (if Execute AI hook is configured)
   - Streams real-time output
3. Configure a "Move Task" hook on In Progress to automatically move completed tasks to "In Review"
4. Review the changes and merge when ready

> **Tip**: Set up hooks on your columns to automate the workflow. See [Hooks System](/docs/hooks) for details.

## Optional Tools

Viban detects available tools at startup and enables features accordingly. Check **Board Settings > System** to see detected tools.

| Tool | Purpose | Feature Enabled |
|------|---------|-----------------|
| `gh` (GitHub CLI) | GitHub integration | Pull Request creation, PR status sync |
| `claude` (Claude Code) | AI-powered task execution | Claude Code executor |
| `codex` (OpenAI Codex) | AI-powered task execution | Codex executor |
| `aider` | AI-powered coding assistant | Aider executor |
| `goose` | AI-powered coding assistant | Goose executor |

### Installing Optional Tools

**GitHub CLI** (for PR functionality):
```bash
# macOS
brew install gh
gh auth login

# Linux
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update && sudo apt install gh
```

**Claude Code** (for Claude AI executor):
```bash
npm install -g @anthropic-ai/claude-code
```

**Aider** (for Aider executor):
```bash
pip install aider-chat
```

## Next Steps

- Learn about [Boards & Tasks](/docs/boards-and-tasks)
- Master [Keyboard Shortcuts](/docs/keyboard-shortcuts) for faster navigation
- Understand [AI Agents](/docs/ai-agents) and how they work
- Set up [Custom Hooks](/docs/custom-hooks) for automation
- Automate recurring work with [Periodical Tasks](/docs/periodical-tasks)
