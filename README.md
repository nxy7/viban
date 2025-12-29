# Viban

A fast-iteration task management tool inspired by [Vibe Kanban](https://vibekanban.com).

The main motivation for this project is the belief that a different tech stack can enable much faster iteration speed for development.

## Tech Stack

- **Backend**: Elixir + Ash Framework + Phoenix Sync
- **Database**: PostgreSQL
- **Frontend**: SolidJS + Bun
- **Real-time**: Phoenix Sync (Electric SQL)

## Prerequisites

- [Nix](https://nixos.org/download.html) with flakes enabled (recommended)
- Or manually: Docker, Elixir 1.17+, Bun

## Quick Start

```bash
# Enter the dev shell (installs all dependencies via Nix)
nix develop

# Start everything with one command
just dev
```

This uses [overmind](https://github.com/DarthSim/overmind) to run all services:
- Docker Compose (PostgreSQL)
- Backend (Elixir/Phoenix on port 4000)
- Frontend (SolidJS on port 3000)

The app will be available at:
- Frontend: http://localhost:3000
- Backend API: http://localhost:4000

### Alternative: Manual Setup

```bash
# Start the database
docker compose up -d db

# In one terminal - backend
cd backend && mix deps.get && mix ash.setup && mix phx.server

# In another terminal - frontend
cd frontend && bun i && bun dev
```

## Project Structure

```
viban/
├── backend/           # Elixir/Ash/Phoenix backend
│   ├── lib/
│   │   ├── viban/           # Core domain (Ash resources)
│   │   └── viban_web/       # Phoenix web layer
│   ├── config/              # Configuration
│   └── priv/                # Migrations, static assets
├── frontend/          # SolidJS frontend
│   ├── src/
│   │   ├── lib/             # Utilities, hooks, sync client
│   │   └── routes/          # Page routes
│   └── package.json
├── Procfile.dev       # Overmind process definitions
├── justfile           # Development commands
├── docker-compose.yml # Development services
└── flake.nix          # Nix dev environment
```

## Development Commands

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

## Overmind Tips

```bash
# Connect to a process log
just connect backend

# Restart a specific service
just restart frontend

# Stop everything
just stop
```

## Architecture

This project uses:

- **Ash Framework** for declarative domain modeling and API generation
- **Phoenix Sync** for real-time data synchronization to the frontend
- **SolidJS** for a reactive, performant frontend
- **Bun** for fast frontend tooling

## License

MIT
