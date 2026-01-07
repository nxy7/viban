# Viban Justfile - Development commands
#
# App runs at: https://localhost:8000 (Phoenix with self-signed HTTPS)

# Default recipe - show available commands
default:
    @just --list

# Start all services with overmind (database, backend, frontend)
dev:
    overmind start -f Procfile.dev

credo:
    cd backend; mix credo --strict

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
    @echo "Starting backend and frontend in parallel..."
    @just backend & just frontend

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
[parallel]
test: test-backend test-frontend

# Run backend tests
test-backend:
    cd backend && mix test

# Run frontend tests
[working-directory: 'frontend']
test-frontend:
    bun run check:fix
    bun run typecheck
    bun run test

# Start services for E2E testing (with E2E_TEST=true)
dev-e2e:
    overmind start -f Procfile.e2e

# Run e2e tests (requires dev-e2e or servers with E2E_TEST=true)
test-e2e:
    cd frontend && bun test:e2e

# Run e2e tests with UI
test-e2e-ui:
    cd frontend && bun test:e2e:ui

# Run e2e tests against production build (same as CI)
# Builds the binary first, then runs tests
test-e2e-prod:
    just build "" true
    ./scripts/run-e2e-prod.sh

# Run e2e tests against existing production binary (skip build)
# Useful for quick re-runs after fixing test code
test-e2e-prod-quick:
    ./scripts/run-e2e-prod.sh

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
    cd frontend && bun run format:fix

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

# Build single executable for distribution
# Use burrito=true to attempt Burrito build (requires OTP 25-27, zig installed)
# Default is standard release which works with any OTP version
build target="" burrito="false":
    #!/usr/bin/env bash
    set -e

    echo "🔨 Building Viban..."
    echo ""

    echo "📦 Building frontend..."
    cd frontend && bun install && bun run build

    echo ""
    echo "📋 Copying frontend assets to backend..."
    rm -rf ../backend/priv/static/_build ../backend/priv/static/index.html 2>/dev/null || true
    cp -r .output/public/* ../backend/priv/static/

    echo ""
    echo "⚙️  Building backend release..."
    cd ../backend
    mix deps.get --only prod

    # First compile all deps (pg_query_ex will fail due to wrong arch libpg_query.a)
    echo "🔧 Compiling dependencies..."
    MIX_ENV=prod mix deps.compile || true

    # Build libpg_query.a from source for current platform (ships with Linux x86_64 precompiled)
    echo "🔧 Building libpg_query for current platform..."
    cd deps/pg_query_ex/c_src/libpg_query && make clean && make libpg_query.a
    cd ../../../..

    # Recompile pg_query_ex with correct native library
    echo "🔧 Recompiling pg_query_ex NIF..."
    MIX_ENV=prod mix deps.compile pg_query_ex --force

    MIX_ENV=prod mix compile
    MIX_ENV=prod mix assets.deploy

    echo ""
    if [ "{{burrito}}" = "true" ]; then
        echo "🌯 Building Burrito single-binary..."
        echo "   Note: Requires OTP 25-27 and zig installed"

        # Use target param, or BURRITO_TARGET env var, or default to current platform
        TARGET="{{target}}"
        if [ -z "$TARGET" ] && [ -n "$BURRITO_TARGET" ]; then
            TARGET="$BURRITO_TARGET"
        fi

        if [ -n "$TARGET" ]; then
            echo "🎯 Target: $TARGET"
            BURRITO_BUILD=1 BURRITO_TARGET="$TARGET" MIX_ENV=prod mix release --overwrite
        else
            echo "🎯 Target: current platform"
            BURRITO_BUILD=1 MIX_ENV=prod mix release --overwrite
        fi
        echo ""
        echo "✅ Burrito build complete!"
        echo "📁 Binary at: backend/burrito_out/"
        ls -la burrito_out/
    else
        echo "📦 Building standard release..."
        MIX_ENV=prod mix release --overwrite
        echo ""
        echo "✅ Build complete!"
        echo "📁 Release at: backend/_build/prod/rel/viban/"
        echo ""
        echo "To run: _build/prod/rel/viban/bin/viban start"
        echo ""
        echo "Deploy mode ports:"
        echo "  App:      https://localhost:7777"
        echo "  Postgres: localhost:17777"
    fi
