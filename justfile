# Viban Justfile - Development commands
#
# App runs at: http://localhost:7777 (Phoenix HTTP)
# Database: SQLite (~/.viban/viban.db or viban_lite.db in dev)

# Default recipe - show available commands
default:
    @just --list

# Start in development mode
dev:
    #!/usr/bin/env bash
    set -e
    [ -f .env ] && set -a && source .env && set +a
    mix deps.get && mix ash.setup && elixir --sname viban --cookie viban -S mix phx.server

credo:
    mix credo --strict

# Setup (deps, migrations)
setup:
    mix deps.get && mix ash.setup

# Start server
server:
    mix phx.server

# Connect to running IEx (when started via 'just dev')
connect:
    iex --sname console --cookie viban --remsh viban

# Run tests
test:
    mix test

# Generate new Ash migration
migrate name:
    mix ash.codegen {{ name }}

# Run database migrations
db-migrate:
    mix ash.migrate

# Reset SQLite database
db-reset:
    rm -f viban_lite.db viban_lite.db-shm viban_lite.db-wal
    mix ash.setup

# Clean all build artifacts
clean:
    rm -rf _build deps
    rm -f viban_lite.db viban_lite.db-shm viban_lite.db-wal

# Format all code
format:
    mix format

# Alias for format
fmt: format

# Kill all dangling processes (use when port is blocked)
kill:
    @echo "Killing dangling Elixir/Phoenix processes..."
    -lsof -ti:7777 | xargs kill -9 2>/dev/null
    @echo "Killing dangling Vite processes..."
    -lsof -ti:5173 | xargs kill -9 2>/dev/null
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

    echo "Building release..."
    mix deps.get --only prod

    echo "Compiling dependencies..."
    MIX_ENV=prod mix deps.compile

    MIX_ENV=prod mix compile

    echo "Building assets with Vite..."
    cd assets && bun install && bun run build
    cd ..
    MIX_ENV=prod mix phx.digest

    echo ""
    if [ "{{ burrito }}" = "true" ]; then
        echo "Building Burrito single-binary..."
        echo "   Note: Requires OTP 25-27 and zig installed"

        # Use target param, or BURRITO_TARGET env var, or default to current platform
        TARGET="{{ target }}"
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
        echo "Binary at: burrito_out/"
        ls -la burrito_out/
    else
        echo "Building standard release..."
        MIX_ENV=prod mix release --overwrite
        echo ""
        echo "Build complete!"
        echo "Release at: _build/prod/rel/viban/"
        echo ""
        echo "To run: _build/prod/rel/viban/bin/viban start"
    fi
