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
2. Start a PostgreSQL container automatically
3. Open your browser to the app

### Requirements for Quick Install

| Tool | Required | Installation |
|------|----------|--------------|
| Docker | **Yes** | [Get Docker](https://docs.docker.com/get-docker/) |
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
| Docker | **Yes** | PostgreSQL database (auto-managed) |
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

- **Backend**: Elixir + Ash Framework + AshSync
- **Database**: PostgreSQL
- **Frontend**: SolidJS + TanStack DB + Bun
- **Real-time**: Electric SQL (via AshSync codegen)

### Prerequisites

- [Nix](https://nixos.org/download.html) with flakes enabled (recommended)
- Or manually: Docker, Elixir 1.17+, Bun

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

This uses [overmind](https://github.com/DarthSim/overmind) to run all services:
- Docker Compose (PostgreSQL)
- Backend (Elixir/Phoenix on port 7771)
- Frontend (SolidJS on port 3000)
- Caddy (HTTPS reverse proxy on port 8000)

The app will be available at:
- **Application**: https://localhost:8000 (via Caddy)
- Backend API: http://localhost:7771 (direct)
- Frontend Dev: http://localhost:3000 (direct)

### Manual Setup (without Nix)

```bash
# Start the database
docker compose up -d db

# In one terminal - backend
cd backend && mix deps.get && mix ash.setup && mix phx.server

# In another terminal - frontend
cd frontend && bun i && bun dev
```

### Development Commands

```bash
just              # Show all available commands
just dev          # Start all services with overmind
just stop         # Stop all overmind processes
just restart db   # Restart a specific process

just backend      # Start only backend
just frontend     # Start only frontend
just db           # Start only database

just test-backend # Run backend tests
just test-e2e     # Run Playwright e2e tests

just migrate name # Generate a new Ash migration
just db-reset     # Reset database
just clean        # Clean all build artifacts
just fmt          # Format all code
```
