# Viban Justfile - Development commands
#
# App runs at: https://localhost:8000 (via Caddy HTTP/2 proxy)

# Default recipe - show available commands
default:
    @just --list

# Start all services with overmind (database, backend, frontend, caddy)
dev:
    overmind start -f Procfile.dev

# Start all services with logging to .logs/ directory
dev-log:
    @mkdir -p .logs
    overmind start -f Procfile.dev 2>&1 | tee .logs/overmind-$(date +%Y%m%d-%H%M%S).log

# View latest overmind log
logs:
    @ls -t .logs/overmind-*.log 2>/dev/null | head -1 | xargs cat 2>/dev/null || echo "No logs found. Run 'just dev-log' to capture logs."

# Tail latest overmind log
logs-tail:
    @ls -t .logs/overmind-*.log 2>/dev/null | head -1 | xargs tail -f 2>/dev/null || echo "No logs found."

# Start all services in foreground (alternative without overmind)
dev-simple:
    @echo "Starting all services..."
    docker compose up -d db
    @echo "Waiting for database..."
    @sleep 3
    @just backend-setup
    @echo "Starting backend, frontend and caddy in parallel..."
    @just backend & just frontend & just caddy

# Trust Caddy's local CA (run once)
caddy-trust:
    caddy trust

# Start Caddy reverse proxy
caddy:
    caddy run --config Caddyfile

# Start only the database
db:
    docker compose up -d db

# Stop all docker services
db-stop:
    docker compose down

# Setup backend (deps, migrations)
backend-setup:
    cd backend && mix deps.get && mix ash.setup

# Start backend server
backend:
    cd backend && mix phx.server

# Connect to running backend IEx (when started via 'just dev')
backend-connect:
    iex --sname console --cookie viban --remsh viban

# Start frontend dev server
frontend:
    cd frontend && bun i && bun dev

# Run all tests (backend + frontend concurrently)
test:
    #!/usr/bin/env bash
    set -e
    just test-backend & pid1=$!
    just test-frontend & pid2=$!
    fail=0
    wait $pid1 || fail=1
    wait $pid2 || fail=1
    exit $fail

# Run backend tests
test-backend:
    cd backend && mix test

# Run frontend tests
test-frontend:
    cd frontend && bun run test

# Start services for E2E testing (with E2E_TEST=true)
dev-e2e:
    overmind start -f Procfile.e2e

# Run e2e tests (requires dev-e2e or servers with E2E_TEST=true)
test-e2e:
    cd frontend && bun test:e2e

# Run e2e tests with UI
test-e2e-ui:
    cd frontend && bun test:e2e:ui

# Generate new Ash migration
migrate name:
    cd backend && mix ash.codegen {{name}}

# Run database migrations
db-migrate:
    cd backend && mix ash.migrate

# Reset database
db-reset:
    cd backend && mix ash.reset

# Open pgweb database UI
pgweb:
    docker compose up -d pgweb
    @echo "PGWeb available at http://localhost:8082"

# Clean all build artifacts
clean:
    rm -rf backend/_build backend/deps
    rm -rf frontend/node_modules frontend/.vinxi frontend/.output
    docker compose down -v

# Format all code
format:
    cd backend && mix format
    cd frontend && npm run format:fix

# Alias for format
fmt: format

# Stop overmind processes
stop:
    overmind stop

# Restart a specific overmind process
restart process:
    overmind restart {{process}}

# Connect to overmind process
connect process:
    overmind connect {{process}}

# Kill all dangling backend processes (use when port is blocked)
kill:
    @echo "Killing dangling Elixir/Phoenix processes..."
    -lsof -ti:7771 | xargs kill -9 2>/dev/null
    -lsof -ti:4000 | xargs kill -9 2>/dev/null
    -pkill -9 -f "beam.smp" 2>/dev/null
    -pkill -9 -f "mix phx.server" 2>/dev/null
    @sleep 1
    @echo "Done. Ports should be free now."
