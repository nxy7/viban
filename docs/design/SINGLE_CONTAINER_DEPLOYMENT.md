# Single Container Deployment Design

## Goal

Create a single Docker container that:
1. Builds frontend and serves it from Elixir
2. Packages PostgreSQL inside the same container
3. Mounts host filesystem for full machine access (git repos, tools, etc.)
4. Provides one-command startup with reproducible environment

## Benefits

- **Reproducible environment**: Same behavior everywhere
- **Simple startup**: `docker run` and you're done
- **No external dependencies**: PostgreSQL is internal, not exposed
- **Full machine access**: Mount filesystem for repo access, tool execution
- **No port conflicts**: Only expose one port (the app)

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Docker Container                      │
│                                                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │              Elixir/Phoenix App                   │   │
│  │  ┌────────────┐  ┌────────────┐  ┌────────────┐  │   │
│  │  │ API Routes │  │  Static    │  │ WebSocket  │  │   │
│  │  │            │  │  (FE SPA)  │  │            │  │   │
│  │  └────────────┘  └────────────┘  └────────────┘  │   │
│  └──────────────────────────────────────────────────┘   │
│                          │                               │
│                          ▼                               │
│  ┌──────────────────────────────────────────────────┐   │
│  │            PostgreSQL (internal)                  │   │
│  │            Socket: /tmp/.s.PGSQL.5432            │   │
│  └──────────────────────────────────────────────────┘   │
│                                                          │
├──────────────────────────────────────────────────────────┤
│  Mounted Volumes:                                        │
│  - /host → / (or specific paths like /home, /Users)     │
│  - /var/run/docker.sock (optional, for docker access)   │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼ Port 4000
                       [Host]
```

## Implementation

### Dockerfile (Multi-stage)

```dockerfile
# =============================================================================
# Stage 1: Build Frontend
# =============================================================================
FROM oven/bun:1 AS frontend-builder

WORKDIR /app/frontend
COPY frontend/package.json frontend/bun.lockb ./
RUN bun install --frozen-lockfile

COPY frontend/ ./
RUN bun run build

# =============================================================================
# Stage 2: Build Backend Release
# =============================================================================
FROM hexpm/elixir:1.17.3-erlang-27.1.2-alpine-3.20.3 AS backend-builder

RUN apk add --no-cache build-base git

WORKDIR /app/backend

# Install hex + rebar
RUN mix local.hex --force && mix local.rebar --force

# Install dependencies
ENV MIX_ENV=prod
COPY backend/mix.exs backend/mix.lock ./
RUN mix deps.get --only prod
RUN mix deps.compile

# Copy frontend build to priv/static
COPY --from=frontend-builder /app/frontend/.output/public ./priv/static/

# Copy backend source
COPY backend/ ./

# Compile and build release
RUN mix compile
RUN mix assets.deploy
RUN mix release

# =============================================================================
# Stage 3: Runtime Image
# =============================================================================
FROM alpine:3.20

RUN apk add --no-cache \
    libstdc++ \
    openssl \
    ncurses-libs \
    postgresql16 \
    postgresql16-contrib \
    git \
    bash \
    su-exec \
    # Tools that agents might need
    curl \
    jq

# Create app user
RUN addgroup -S viban && adduser -S viban -G viban

# PostgreSQL data directory
RUN mkdir -p /var/lib/postgresql/data && chown -R postgres:postgres /var/lib/postgresql

# Copy release
WORKDIR /app
COPY --from=backend-builder /app/backend/_build/prod/rel/viban ./
RUN chown -R viban:viban /app

# Startup script
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENV HOME=/app
ENV PORT=4000
ENV PHX_HOST=localhost
ENV DATABASE_URL=postgres://viban:viban@localhost/viban

EXPOSE 4000

ENTRYPOINT ["/entrypoint.sh"]
CMD ["start"]
```

### Entrypoint Script

```bash
#!/bin/bash
set -e

# =============================================================================
# Initialize PostgreSQL if needed
# =============================================================================
PGDATA="/var/lib/postgresql/data"

if [ ! -s "$PGDATA/PG_VERSION" ]; then
    echo "Initializing PostgreSQL database..."
    su-exec postgres initdb -D "$PGDATA"

    # Configure for local socket connection only (no TCP)
    echo "listen_addresses = ''" >> "$PGDATA/postgresql.conf"
    echo "unix_socket_directories = '/tmp'" >> "$PGDATA/postgresql.conf"

    # Enable logical replication for Electric SQL
    echo "wal_level = logical" >> "$PGDATA/postgresql.conf"
    echo "max_replication_slots = 5" >> "$PGDATA/postgresql.conf"
    echo "max_wal_senders = 10" >> "$PGDATA/postgresql.conf"

    # Trust local connections
    echo "local all all trust" > "$PGDATA/pg_hba.conf"
fi

# =============================================================================
# Start PostgreSQL
# =============================================================================
echo "Starting PostgreSQL..."
su-exec postgres pg_ctl -D "$PGDATA" -l /var/log/postgresql.log start

# Wait for PostgreSQL to be ready
until su-exec postgres pg_isready -h /tmp; do
    echo "Waiting for PostgreSQL..."
    sleep 1
done

# Create database and user if needed
su-exec postgres psql -h /tmp -c "CREATE USER viban WITH PASSWORD 'viban' CREATEDB;" 2>/dev/null || true
su-exec postgres psql -h /tmp -c "CREATE DATABASE viban OWNER viban;" 2>/dev/null || true
su-exec postgres psql -h /tmp -c "ALTER USER viban WITH REPLICATION;" 2>/dev/null || true

# =============================================================================
# Run Migrations
# =============================================================================
echo "Running migrations..."
/app/bin/viban eval "Viban.Release.migrate()"

# =============================================================================
# Start Application
# =============================================================================
echo "Starting Viban..."
exec su-exec viban /app/bin/viban "$@"
```

### Frontend Serving from Phoenix

Update `endpoint.ex` to serve the SPA:

```elixir
# In lib/viban_web/endpoint.ex

# Serve static files (including frontend build)
plug Plug.Static,
  at: "/",
  from: :viban,
  gzip: true,
  only: ~w(assets fonts images favicon.ico robots.txt index.html)

# ... existing plugs ...

# Add SPA fallback at the end of router.ex or as a plug
# This serves index.html for all non-API routes (SPA routing)
```

Add a fallback controller for SPA routing:

```elixir
# In lib/viban_web/controllers/spa_controller.ex
defmodule VibanWeb.SPAController do
  use VibanWeb, :controller

  def index(conn, _params) do
    conn
    |> put_resp_header("content-type", "text/html; charset=utf-8")
    |> send_file(200, Application.app_dir(:viban, "priv/static/index.html"))
  end
end

# In router.ex, add at the very end:
scope "/", VibanWeb do
  get "/*path", SPAController, :index
end
```

### Release Configuration

Create `rel/env.sh.eex`:

```bash
#!/bin/sh

# Use Unix socket for PostgreSQL
export DATABASE_URL="${DATABASE_URL:-postgres://viban:viban@/viban?host=/tmp}"
```

Update `mix.exs` for release:

```elixir
def project do
  [
    # ... existing config
    releases: [
      viban: [
        include_executables_for: [:unix],
        applications: [runtime_tools: :permanent]
      ]
    ]
  ]
end
```

### Release Module

```elixir
# lib/viban/release.ex
defmodule Viban.Release do
  @moduledoc """
  Release tasks for database migrations.
  """

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Application.fetch_env!(:viban, :ecto_repos)
  end

  defp load_app do
    Application.load(:viban)
  end
end
```

## Usage

### Build

```bash
docker build -t viban:latest .
```

### Run

```bash
# Basic run
docker run -p 4000:4000 viban:latest

# With filesystem access (for git repos, tools)
docker run -p 4000:4000 \
  -v /Users:/Users:rw \
  -v /home:/home:rw \
  -e SECRET_KEY_BASE="$(mix phx.gen.secret)" \
  -e ANTHROPIC_API_KEY="your-key" \
  viban:latest

# With persistent database
docker run -p 4000:4000 \
  -v viban-pgdata:/var/lib/postgresql/data \
  -v /Users:/Users:rw \
  viban:latest

# Development mode with live code (mount source)
docker run -p 4000:4000 \
  -v $(pwd):/app/src:ro \
  -v /Users:/Users:rw \
  viban:latest
```

### Docker Compose (optional convenience)

```yaml
version: "3.8"

services:
  viban:
    build: .
    ports:
      - "4000:4000"
    volumes:
      # Persistent database
      - pgdata:/var/lib/postgresql/data
      # Host filesystem access
      - /Users:/Users:rw
      - /home:/home:rw
      # SSH keys for git operations
      - ~/.ssh:/home/viban/.ssh:ro
    environment:
      - SECRET_KEY_BASE=${SECRET_KEY_BASE}
      - ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}
      - GH_CLIENT_ID=${GH_CLIENT_ID}
      - GH_CLIENT_SECRET=${GH_CLIENT_SECRET}

volumes:
  pgdata:
```

## Security Considerations

### Filesystem Mount Risks

Mounting the host filesystem gives the container (and AI agents) full access:

```bash
# More restrictive mount (specific directories only)
docker run \
  -v ~/projects:/projects:rw \
  -v ~/repos:/repos:rw \
  viban:latest
```

### PostgreSQL Security

- PostgreSQL only listens on Unix socket (no TCP)
- No external port exposure
- Database credentials stay inside container

### Recommended Mounts

| Mount | Purpose | Mode |
|-------|---------|------|
| `/Users` or `/home` | Access to git repos | rw |
| `~/.ssh` | Git SSH authentication | ro |
| `~/.gitconfig` | Git user config | ro |
| `~/.config/claude` | Claude CLI config | ro |

## Alternative: Separate Data Volume

For cleaner separation:

```bash
# Create a dedicated workspace directory
mkdir -p ~/viban-workspace

# Mount only that directory
docker run -p 4000:4000 \
  -v ~/viban-workspace:/workspace:rw \
  -v viban-pgdata:/var/lib/postgresql/data \
  viban:latest
```

Then configure Viban to clone repos into `/workspace`.

## Electric SQL Considerations

Electric SQL needs PostgreSQL with logical replication. The entrypoint configures:
- `wal_level = logical`
- `max_replication_slots = 5`
- `max_wal_senders = 10`

The Electric sync service runs as part of the Phoenix app (via `phoenix_sync`).

## Image Size Optimization

Expected sizes:
- Frontend build: ~50MB
- Elixir release: ~50MB
- PostgreSQL: ~100MB
- Base Alpine + tools: ~50MB
- **Total: ~250MB**

To reduce further:
- Use `--release` flag for Bun build
- Strip debug symbols from Erlang release
- Use multi-stage to exclude build tools

## Open Questions

1. **Claude CLI / other agents**: Should these be pre-installed in container or accessed from host?
   - Option A: Install in container (adds size, version locked)
   - Option B: Mount from host `~/.local/bin` or similar (flexible)

2. **Git credentials**: Best practice for SSH keys in container?
   - Mount `~/.ssh` read-only seems reasonable

3. **Docker-in-Docker**: If agents need to run docker commands?
   - Mount `/var/run/docker.sock` (security implications)

4. **Hot reload in dev**: Worth supporting mounted source with `iex -S mix`?
