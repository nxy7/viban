# Viban Justfile - Development commands
#
# App runs at: https://localhost:7777 (Caddy HTTPS -> Phoenix HTTP)
# Architecture: Caddy (:7777 HTTPS) -> Phoenix (:7780 HTTP) -> Vite (:7778 HTTP)

# Default recipe - show available commands
default:
    @just --list

# Start all services (database, caddy, backend, frontend)
dev:
    #!/usr/bin/env bash
    set -a && source .env && set +a
    trap 'kill 0' EXIT
    docker compose up db &
    sleep 3
    caddy run --config Caddyfile &
    (cd backend && mix deps.get && mix ash.setup && elixir --sname viban --cookie viban -S mix phx.server) &
    (cd frontend && bun i && bun dev) &
    wait

credo:
    cd backend; mix credo --strict

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
    #!/usr/bin/env bash
    set -a && source .env && set +a
    trap 'kill 0' EXIT
    docker compose up db &
    sleep 3
    caddy run --config Caddyfile &
    (cd backend && E2E_TEST=true mix phx.server) &
    (cd frontend && bun dev) &
    wait

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
    just _run-e2e-prod

# Run e2e tests against existing production binary (skip build)
# Useful for quick re-runs after fixing test code
test-e2e-prod-quick:
    just _run-e2e-prod

# Internal: run e2e tests against production binary
_run-e2e-prod binary_path="":
    #!/usr/bin/env bash
    set -e

    BINARY_PATH="{{binary_path}}"

    if [ -z "$BINARY_PATH" ]; then
        OS=$(uname -s | tr '[:upper:]' '[:lower:]')
        ARCH=$(uname -m)

        [ "$OS" = "darwin" ] && OS="macos"
        [ "$ARCH" = "x86_64" ] && ARCH="intel"
        [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ] && ARCH="arm"

        PLATFORM="${OS}_${ARCH}"

        if [ -f "backend/burrito_out/viban_${PLATFORM}" ]; then
            BINARY_PATH="backend/burrito_out/viban_${PLATFORM}"
        elif [ -f "./viban_${PLATFORM}" ]; then
            BINARY_PATH="./viban_${PLATFORM}"
        elif ls ./viban_* 1>/dev/null 2>&1; then
            BINARY_PATH=$(ls ./viban_* | head -1)
        else
            echo "❌ No binary found for platform: $PLATFORM"
            echo "   Run 'just build \"\" true' first"
            exit 1
        fi
    fi

    echo "📦 Using binary: $BINARY_PATH"
    [ ! -x "$BINARY_PATH" ] && chmod +x "$BINARY_PATH"

    echo "🚀 Starting production server..."
    E2E_TEST=true "$BINARY_PATH" > /tmp/viban-e2e.log 2>&1 &
    SERVER_PID=$!

    cleanup() {
        echo "🛑 Stopping server (PID: $SERVER_PID)..."
        kill $SERVER_PID 2>/dev/null || true
        docker stop viban-postgres 2>/dev/null || true
    }
    trap cleanup EXIT

    echo "⏳ Waiting for server to start..."
    for i in {1..60}; do
        if curl -sk https://localhost:7777 > /dev/null 2>&1; then
            echo "✅ Server is ready!"
            break
        fi
        echo "   Attempt $i/60..."
        sleep 2
    done

    if ! curl -sk https://localhost:7777 > /dev/null 2>&1; then
        echo "❌ Server failed to start. Logs:"
        cat /tmp/viban-e2e.log
        exit 1
    fi

    echo "🧪 Running E2E tests..."
    cd frontend && bun run test:e2e:prod

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

# Kill all dangling backend processes (use when port is blocked)
kill:
    @echo "Killing dangling Elixir/Phoenix/Caddy processes..."
    -lsof -ti:7777 | xargs kill -9 2>/dev/null
    -lsof -ti:7778 | xargs kill -9 2>/dev/null
    -lsof -ti:7780 | xargs kill -9 2>/dev/null
    -pkill -9 -f "viban.*phx.server" 2>/dev/null
    -pkill -9 -f "vinxi" 2>/dev/null
    -pkill -9 -f "caddy run" 2>/dev/null
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
