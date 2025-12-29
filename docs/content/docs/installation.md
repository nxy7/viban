---
title: Installation
description: Detailed installation instructions for all Viban components.
---

# Installation

This guide covers detailed installation instructions for all Viban components.

## System Requirements

### Required Software

| Software | Minimum Version | Recommended |
|----------|----------------|-------------|
| Elixir | 1.15 | 1.17+ |
| Erlang/OTP | 26 | 27+ |
| Node.js | 20 | 22+ |
| PostgreSQL | 15 | 16+ |
| Git | 2.30 | Latest |

### AI Agent Requirements

At least one of the following AI agents must be installed:

- **Claude Code CLI**: `npm install -g @anthropic-ai/claude-code`
- **Codex CLI**: OpenAI Codex setup
- **Cursor**: Cursor editor with Agent mode

## Backend Setup

### 1. Install Elixir Dependencies

```bash
cd backend
mix deps.get
```

### 2. Configure Environment

Create a `.env` file in the backend directory:

```bash
# Database
DATABASE_URL=postgres://localhost/viban_dev

# Secret Key (generate with: mix phx.gen.secret)
SECRET_KEY_BASE=your-secret-key-here

# GitHub OAuth (optional)
GITHUB_CLIENT_ID=your-github-client-id
GITHUB_CLIENT_SECRET=your-github-client-secret
```

### 3. Set Up Database

```bash
mix ecto.create
mix ecto.migrate
```

### 4. Start the Server

```bash
mix phx.server
```

The backend will be available at `http://localhost:4000`.

## Frontend Setup

### 1. Install Dependencies

Using Bun (recommended):
```bash
cd frontend
bun install
```

Or using npm:
```bash
cd frontend
npm install
```

### 2. Configure Environment

Create a `.env` file:

```bash
VITE_API_URL=http://localhost:4000
VITE_ELECTRIC_URL=http://localhost:3000
```

### 3. Start Development Server

```bash
bun dev
```

The frontend will be available at `http://localhost:3000`.

## Electric SQL Setup

Viban uses Electric SQL for real-time synchronization. Install and configure:

```bash
# Pull the Electric image
docker pull electricsql/electric

# Start Electric (connects to your PostgreSQL)
docker run -e DATABASE_URL=postgres://localhost/viban_dev electricsql/electric
```

## Claude Code Setup

### 1. Install Claude Code CLI

```bash
npm install -g @anthropic-ai/claude-code
```

### 2. Authenticate

```bash
claude login
```

### 3. Verify Installation

```bash
claude --version
```

## Production Deployment

For production deployment, see our Deployment Guide.
