# Viban

A fast-iteration task management tool inspired by [Vibe Kanban](https://vibekanban.com).

The main motivation for this project is the belief that a different tech stack can enable much faster iteration speed for development.

## Quick Start

### Prerequisites

| Tool | Required | Installation |
|------|----------|--------------|
| Elixir | **Yes** | [Get Elixir](https://elixir-lang.org/install.html) |
| Git | **Yes** | For version control and worktree management |

### Install & Run

```bash
# Clone and run
git clone https://github.com/nxy7/viban
cd viban
mix deps.get && mix ash.setup && mix phx.server
```

The app will be available at http://localhost:7777

### Alternative: Direct Binary Download

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

## Requirements

### Core Requirements

| Tool | Required | Purpose |
|------|----------|---------|
| Elixir | **Yes** | Runtime |
| Git | **Yes** | Version control, worktree management |

### Optional Tools

Viban detects available tools at startup and enables features accordingly. Check **Board Settings > System** to see detected tools.

| Tool | Purpose | Feature Enabled |
|------|---------|-----------------|
| `gh` (GitHub CLI) | GitHub integration | Pull Request creation, PR status sync |
| `claude` (Claude Code) | AI-powered task execution | Claude Code executor |

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

---

## Development

This section covers running the project locally for development.

### Tech Stack

- **Backend**: Elixir + Ash Framework + Phoenix LiveView
- **Frontend**: LiveVue (Vue 3 components in LiveView)
- **Database**: SQLite (via AshSqlite)
- **Real-time**: Phoenix PubSub

### Prerequisites

- [Nix](https://nixos.org/download.html) with flakes enabled (recommended)
- Or manually: Elixir 1.18+, Erlang 27+

### Running the Project

```bash
# Enter the dev shell (installs all dependencies via Nix)
nix develop

# Start with one command
just dev
```

The app will be available at http://localhost:7777

#### Manual Setup (without Nix)

```bash
mix deps.get && mix ash.setup && mix phx.server
```

### Project Structure

```
viban/
├── lib/
│   ├── viban/           # Core domain (Ash resources)
│   └── viban_web/       # Phoenix web layer (LiveView)
├── assets/              # Frontend assets (Vue components, JS, CSS)
├── config/              # Configuration
├── priv/                # Migrations, static assets
├── test/                # Tests
├── justfile             # Development commands
└── flake.nix            # Nix dev environment
```

### Development Commands

```bash
just              # Show all available commands
just dev          # Start development server

just test         # Run tests
just credo        # Run Credo linter

just migrate name # Generate a new Ash migration
just db-reset     # Reset database
just clean        # Clean all build artifacts
just fmt          # Format all code
just kill         # Kill dangling processes (if port is blocked)
```

### Architecture

This project uses:

- **Ash Framework** for declarative domain modeling
- **Phoenix LiveView** for server-rendered real-time UI
- **LiveVue** for embedding Vue 3 components in LiveView
- **SQLite** for simple, file-based persistence
- **Phoenix PubSub** for real-time updates

## License

Polyform Noncommercial License 1.0.0
