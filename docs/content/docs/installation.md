---
title: Installation
description: Detailed installation instructions for Viban.
---

# Installation

This guide covers all installation options for Viban.

## Quick Install (Recommended)

The easiest way to run Viban is using npx:

```bash
npx @nxy7/viban
```

This will:
1. Download the appropriate binary for your platform
2. Open your browser to the app

### Requirements for Quick Install

| Tool | Required | Installation |
|------|----------|--------------|
| Node.js | **Yes** | [Get Node.js](https://nodejs.org/) |

## Direct Binary Download

You can download the binary directly from [GitHub Releases](https://github.com/nxy7/viban/releases):

```bash
# macOS (Apple Silicon)
curl -L https://github.com/nxy7/viban/releases/latest/download/viban-macos_arm -o viban
chmod +x viban
./viban

# macOS (Intel)
curl -L https://github.com/nxy7/viban/releases/latest/download/viban-macos_intel -o viban
chmod +x viban
./viban

# Linux (x64)
curl -L https://github.com/nxy7/viban/releases/latest/download/viban-linux_intel -o viban
chmod +x viban
./viban

# Linux (ARM)
curl -L https://github.com/nxy7/viban/releases/latest/download/viban-linux_arm -o viban
chmod +x viban
./viban
```

### Requirements for Binary

| Tool | Required | Purpose |
|------|----------|---------|
| Git | **Yes** | Version control, worktree management |

## HTTPS Certificate Note

Viban uses HTTPS with a self-signed certificate for HTTP/2 support. Your browser may show a security warning on first visit - this is expected. Click "Advanced" → "Proceed" to continue.

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

---

## Development Setup

This section is for contributors who want to run Viban from source.

### Tech Stack

- **Backend**: Elixir + Ash Framework + Phoenix LiveView
- **Database**: SQLite (via AshSqlite)
- **Frontend**: LiveVue (Vue 3 components in LiveView)
- **Real-time**: Phoenix PubSub

### Prerequisites

- [Nix](https://nixos.org/download.html) with flakes enabled (recommended)
- Or manually: Elixir 1.18+, Erlang 27+

### Running from Source

```bash
# Clone the repository
git clone https://github.com/nxy7/viban.git
cd viban

# Enter the dev shell (installs all dependencies via Nix)
nix develop

# Start everything with one command
just dev
```

The app will be available at http://localhost:7777

### Manual Setup (without Nix)

```bash
# Install dependencies and start the server
mix deps.get && mix ash.setup && mix phx.server
```

### Development Commands

```bash
just              # Show all available commands
just dev          # Start development server

just test         # Run tests

just migrate name # Generate a new Ash migration
just db-reset     # Reset database
just clean        # Clean all build artifacts
just fmt          # Format all code
just kill         # Kill dangling processes (if port is blocked)
```
