#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
FRONTEND_DIR="$ROOT_DIR/frontend"
BACKEND_DIR="$ROOT_DIR/backend"
STATIC_DIR="$BACKEND_DIR/priv/static"

echo "=== Building Viban ==="

echo "1. Building frontend..."
cd "$FRONTEND_DIR"
bun install
bun run build

echo "2. Copying frontend assets to Phoenix..."
rm -rf "$STATIC_DIR/_build" "$STATIC_DIR/index.html" "$STATIC_DIR/sounds" "$STATIC_DIR/favicon.ico"
cp -r "$FRONTEND_DIR/.output/public/_build" "$STATIC_DIR/_build"
cp -r "$FRONTEND_DIR/.output/public/sounds" "$STATIC_DIR/sounds" 2>/dev/null || true
cp "$FRONTEND_DIR/.output/public/index.html" "$STATIC_DIR/index.html"
cp "$FRONTEND_DIR/.output/public/favicon.ico" "$STATIC_DIR/favicon.ico" 2>/dev/null || true

echo "3. Building backend release..."
cd "$BACKEND_DIR"
mix deps.get --only prod
MIX_ENV=prod mix compile
MIX_ENV=prod mix release --overwrite

echo ""
echo "=== Build complete! ==="
echo "Release location: $BACKEND_DIR/_build/prod/rel/viban"
echo ""
echo "To run:"
echo "  DATABASE_URL=ecto://user:pass@localhost/viban_prod \\"
echo "  SECRET_KEY_BASE=\$(openssl rand -base64 48) \\"
echo "  PHX_HOST=localhost \\"
echo "  $BACKEND_DIR/_build/prod/rel/viban/bin/viban start"
