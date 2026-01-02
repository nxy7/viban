# Viban All-in-One Dockerfile
# This image contains the complete Viban application:
# - PostgreSQL database (runs as a subprocess)
# - Elixir/Phoenix backend
# - SolidJS frontend (pre-built, served via Node.js)
# - Caddy reverse proxy (routes all traffic through single port)
#
# Usage:
#   docker build -t viban .
#   docker run -it --rm \
#     -p 8000:8000 \
#     -v /:/host:ro \
#     -v viban-data:/var/lib/postgresql/data \
#     -e SECRET_KEY_BASE=$(mix phx.gen.secret) \
#     viban
#
# The /host mount provides read-only access to the host filesystem
# for AI agents like Claude Code to work on host projects.

# ==============================================================================
# Stage 1: Build the Elixir backend
# ==============================================================================
FROM elixir:1.18-otp-27-alpine AS backend-builder

RUN apk add --no-cache \
    git \
    build-base \
    nodejs \
    npm

WORKDIR /app/backend

# Install Elixir dependencies
COPY backend/mix.exs backend/mix.lock ./
RUN mix local.hex --force && \
    mix local.rebar --force && \
    MIX_ENV=prod mix deps.get --only prod

# Copy backend source
COPY backend/ ./

# Compile and build release
RUN MIX_ENV=prod mix compile && \
    MIX_ENV=prod mix assets.deploy && \
    MIX_ENV=prod mix release

# ==============================================================================
# Stage 2: Build the frontend
# ==============================================================================
FROM oven/bun:1-alpine AS frontend-builder

WORKDIR /app/frontend

# Install dependencies
COPY frontend/package.json frontend/bun.lock* ./
RUN bun install --frozen-lockfile

# Copy frontend source and build
COPY frontend/ ./
RUN bun run build

# ==============================================================================
# Stage 3: Runtime image (use same base as build for OpenSSL compatibility)
# ==============================================================================
FROM elixir:1.18-otp-27-alpine AS runtime

# Install runtime dependencies
RUN apk add --no-cache \
    # PostgreSQL
    postgresql16 \
    postgresql16-contrib \
    # Caddy for reverse proxy
    caddy \
    # Process supervisor
    supervisor \
    # Common utilities that may be needed by AI agents
    git \
    curl \
    bash \
    # For health checks
    postgresql-client \
    # For Bun
    gcompat libgcc

# Install Bun for frontend server
RUN curl -fsSL https://bun.sh/install | bash && \
    mv /root/.bun/bin/bun /usr/local/bin/ && \
    rm -rf /root/.bun

# Create non-root user for the app (but PostgreSQL needs its own user)
RUN addgroup -g 1000 viban && \
    adduser -u 1000 -G viban -D viban

# Set up PostgreSQL data directory
RUN mkdir -p /var/lib/postgresql/data /run/postgresql && \
    chown -R postgres:postgres /var/lib/postgresql /run/postgresql

# Set up app directories
WORKDIR /app

# Copy backend release
COPY --from=backend-builder /app/backend/_build/prod/rel/viban ./backend

# Copy frontend build
COPY --from=frontend-builder /app/frontend/.output ./frontend

# Copy Caddy configuration
COPY <<'EOF' /etc/caddy/Caddyfile
{
    auto_https off
    admin off
}

:8000 {
    # Backend API routes
    handle /api/* {
        reverse_proxy localhost:4000
    }

    # Auth routes (OAuth flow)
    handle /auth/* {
        reverse_proxy localhost:4000
    }

    # MCP routes (for AI agents)
    handle /mcp/* {
        reverse_proxy localhost:4000
    }

    # Tidewave MCP for AI debugging (disabled in prod)
    # handle /tidewave/* {
    #     reverse_proxy localhost:4000
    # }

    # Phoenix WebSocket (for channels/live updates)
    handle /socket/* {
        reverse_proxy localhost:4000
    }

    # Phoenix LiveView WebSocket
    handle /live/* {
        reverse_proxy localhost:4000
    }

    # Everything else goes to frontend
    handle {
        reverse_proxy localhost:3000
    }

    encode gzip
}
EOF

# Copy supervisor configuration
COPY <<'EOF' /etc/supervisor/conf.d/viban.conf
[supervisord]
nodaemon=true
user=root
logfile=/var/log/supervisord.log
pidfile=/var/run/supervisord.pid

[program:postgresql]
command=/usr/bin/postgres -D /var/lib/postgresql/data -c listen_addresses='127.0.0.1' -c wal_level=logical -c max_wal_senders=10 -c max_replication_slots=10
user=postgres
autostart=true
autorestart=true
priority=10
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0

[program:backend]
command=/app/backend/bin/viban start
user=viban
autostart=true
autorestart=true
priority=20
startsecs=5
startretries=3
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
environment=DATABASE_URL="ecto://postgres:postgres@127.0.0.1/viban_prod",PHX_SERVER="true",PORT="4000",SECRET_KEY_BASE="%(ENV_SECRET_KEY_BASE)s",PHX_HOST="%(ENV_PHX_HOST)s"

[program:frontend]
command=/usr/local/bin/bun /app/frontend/server/index.mjs
user=viban
directory=/app/frontend
autostart=true
autorestart=true
priority=20
startsecs=3
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
environment=PORT="3000",NODE_ENV="production"

[program:caddy]
command=/usr/sbin/caddy run --config /etc/caddy/Caddyfile
user=root
autostart=true
autorestart=true
priority=30
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
EOF

# Create init script for database setup
COPY <<'INITSCRIPT' /app/init.sh
#!/bin/bash
set -e

echo "=== Viban All-in-One Container Starting ==="

# Validate required environment variables
if [ -z "$SECRET_KEY_BASE" ]; then
    echo "ERROR: SECRET_KEY_BASE environment variable is required."
    echo "Generate one with: mix phx.gen.secret"
    exit 1
fi

# Initialize PostgreSQL if needed
if [ ! -f /var/lib/postgresql/data/PG_VERSION ]; then
    echo "Initializing PostgreSQL database..."
    su postgres -c "initdb -D /var/lib/postgresql/data"

    # Start PostgreSQL temporarily
    su postgres -c "pg_ctl -D /var/lib/postgresql/data -o '-c listen_addresses=127.0.0.1' start"
    sleep 3

    # Create database
    su postgres -c "psql -c \"CREATE DATABASE viban_prod;\""

    # Stop PostgreSQL (supervisor will start it)
    su postgres -c "pg_ctl -D /var/lib/postgresql/data stop"
    sleep 1
fi

# Export environment variables for supervisor to pick up
export DATABASE_URL="ecto://postgres:postgres@127.0.0.1/viban_prod"
export PHX_HOST="${PHX_HOST:-localhost}"

# Start supervisor (runs all services)
echo "Starting services..."
supervisord -c /etc/supervisor/conf.d/viban.conf &
SUPERVISOR_PID=$!

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL to be ready..."
for i in $(seq 1 30); do
    if pg_isready -h 127.0.0.1 -U postgres 2>/dev/null; then
        echo "PostgreSQL is ready!"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "ERROR: PostgreSQL failed to start within 30 seconds"
        exit 1
    fi
    sleep 1
done

# Run migrations
echo "Running database migrations..."
DATABASE_URL="$DATABASE_URL" SECRET_KEY_BASE="$SECRET_KEY_BASE" /app/backend/bin/viban eval "Viban.Release.migrate()"

echo "=== Viban is running on http://localhost:8000 ==="

# Keep supervisor running
wait $SUPERVISOR_PID
INITSCRIPT
RUN chmod +x /app/init.sh

# Set ownership
RUN chown -R viban:viban /app

# Expose ports
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8000/api/health || exit 1

# Environment variables with defaults
ENV SECRET_KEY_BASE=""
ENV PHX_HOST="localhost"
ENV DATABASE_URL="ecto://postgres:postgres@127.0.0.1/viban_prod"

# Start command
CMD ["/app/init.sh"]
