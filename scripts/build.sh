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

RELEASE_DIR="$BACKEND_DIR/_build/prod/rel/viban"

echo ""
echo "=== Build complete! ==="
echo "Release: $RELEASE_DIR"
echo ""
echo "To run Viban:"
echo ""
echo "  1. Start postgres:"
echo "     docker run -d --name viban-db -p 5432:5432 \\"
echo "       -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=viban_prod \\"
echo "       postgres:16-alpine -c wal_level=logical"
echo ""
echo "  2. Run migrations (first time only):"
echo "     DATABASE_URL=ecto://postgres:postgres@localhost/viban_prod \\"
echo "     SECRET_KEY_BASE=\$(openssl rand -base64 48) \\"
echo "     $RELEASE_DIR/bin/viban eval 'Viban.Release.migrate()'"
echo ""
echo "  3. Start the server:"
echo "     DATABASE_URL=ecto://postgres:postgres@localhost/viban_prod \\"
echo "     SECRET_KEY_BASE=\$(openssl rand -base64 48) \\"
echo "     PHX_HOST=localhost \\"
echo "     $RELEASE_DIR/bin/viban start"
echo ""
echo "NOTE: The release requires Erlang/OTP to be installed on the target machine."
echo "      For single-binary builds (no Erlang needed), use Burrito with OTP <= 27:"
echo "      BURRITO_BUILD=1 MIX_ENV=prod mix release"
