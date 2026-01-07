#!/usr/bin/env bash
set -e

# Run E2E tests against a production build
# Usage: ./scripts/run-e2e-prod.sh [binary_path]
# If no binary path provided, auto-detects platform and finds correct binary

BINARY_PATH="${1:-}"

if [ -z "$BINARY_PATH" ]; then
    # Detect current platform
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)

    if [ "$OS" = "darwin" ]; then
        OS="macos"
    fi

    if [ "$ARCH" = "x86_64" ]; then
        ARCH="intel"
    elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
        ARCH="arm"
    fi

    PLATFORM="${OS}_${ARCH}"

    # Try to find the binary for current platform
    if [ -f "backend/burrito_out/viban_${PLATFORM}" ]; then
        BINARY_PATH="backend/burrito_out/viban_${PLATFORM}"
    elif [ -f "./viban_${PLATFORM}" ]; then
        BINARY_PATH="./viban_${PLATFORM}"
    elif ls ./viban_* 1>/dev/null 2>&1; then
        # Fallback for CI where binary name is known
        BINARY_PATH=$(ls ./viban_* | head -1)
    else
        echo "❌ No binary found for platform: $PLATFORM"
        echo "   Either:"
        echo "   - Run 'just build \"\" true' first"
        echo "   - Or provide binary path: $0 /path/to/viban_binary"
        exit 1
    fi
fi

echo "📦 Using binary: $BINARY_PATH"

if [ ! -x "$BINARY_PATH" ]; then
    echo "Making binary executable..."
    chmod +x "$BINARY_PATH"
fi

echo ""
echo "🚀 Starting production server..."
E2E_TEST=true "$BINARY_PATH" > /tmp/viban-e2e.log 2>&1 &
SERVER_PID=$!

cleanup() {
    echo ""
    echo "🛑 Stopping server (PID: $SERVER_PID)..."
    kill $SERVER_PID 2>/dev/null || true
    # Also kill any Docker postgres started by the binary
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

echo ""
echo "🧪 Running E2E tests..."
cd frontend && bun run test:e2e:prod
