# Viban Justfile - Development commands
#
# App runs at: http://localhost:7777 (Phoenix HTTP)

# Default recipe - show available commands
default:
    @just --list

# Start all services (database, backend)
dev:
    #!/usr/bin/env bash
    set -a && source .env && set +a
    trap 'kill 0' EXIT
    docker compose up db &
    sleep 3
    (cd backend && mix deps.get && mix ash.setup && elixir --sname viban --cookie viban -S mix phx.server) &
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

# Run backend tests
test:
    cd backend && mix test

# Start services for E2E testing (with E2E_TEST=true)
dev-e2e:
    #!/usr/bin/env bash
    set -a && source .env && set +a
    trap 'kill 0' EXIT
    docker compose up db &
    sleep 3
    (cd backend && E2E_TEST=true mix phx.server) &
    wait

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
    docker compose down -v

# Format all code
format:
    cd backend && mix format

# Alias for format
fmt: format

# Kill all dangling backend processes (use when port is blocked)
kill:
    @echo "Killing dangling Elixir/Phoenix processes..."
    -lsof -ti:7777 | xargs kill -9 2>/dev/null
    -pkill -9 -f "viban.*phx.server" 2>/dev/null
    @sleep 1
    @echo "Done. Ports should be free now."

# Build single executable for distribution
# Use burrito=true to attempt Burrito build (requires OTP 25-27, zig installed)
# Default is standard release which works with any OTP version
build target="" burrito="false":
    #!/usr/bin/env bash
    set -e

    echo "Building Viban..."
    echo ""

    echo "Building backend release..."
    cd backend
    mix deps.get --only prod

    # First compile all deps (pg_query_ex will fail due to wrong arch libpg_query.a)
    echo "Compiling dependencies..."
    MIX_ENV=prod mix deps.compile || true

    # Build libpg_query.a from source for current platform (ships with Linux x86_64 precompiled)
    echo "Building libpg_query for current platform..."
    cd deps/pg_query_ex/c_src/libpg_query && make clean && make libpg_query.a
    cd ../../../..

    # Recompile pg_query_ex with correct native library
    echo "Recompiling pg_query_ex NIF..."
    MIX_ENV=prod mix deps.compile pg_query_ex --force

    MIX_ENV=prod mix compile
    MIX_ENV=prod mix assets.deploy

    echo ""
    if [ "{{burrito}}" = "true" ]; then
        echo "Building Burrito single-binary..."
        echo "   Note: Requires OTP 25-27 and zig installed"

        # Use target param, or BURRITO_TARGET env var, or default to current platform
        TARGET="{{target}}"
        if [ -z "$TARGET" ] && [ -n "$BURRITO_TARGET" ]; then
            TARGET="$BURRITO_TARGET"
        fi

        if [ -n "$TARGET" ]; then
            echo "Target: $TARGET"
            BURRITO_BUILD=1 BURRITO_TARGET="$TARGET" MIX_ENV=prod mix release --overwrite
        else
            echo "Target: current platform"
            BURRITO_BUILD=1 MIX_ENV=prod mix release --overwrite
        fi
        echo ""
        echo "Burrito build complete!"
        echo "Binary at: backend/burrito_out/"
        ls -la burrito_out/
    else
        echo "Building standard release..."
        MIX_ENV=prod mix release --overwrite
        echo ""
        echo "Build complete!"
        echo "Release at: backend/_build/prod/rel/viban/"
        echo ""
        echo "To run: _build/prod/rel/viban/bin/viban start"
        echo ""
        echo "Deploy mode ports:"
        echo "  App:      http://localhost:7777"
        echo "  Postgres: localhost:17777"
    fi
