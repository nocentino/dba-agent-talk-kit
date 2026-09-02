#!/usr/bin/env bash
# Clean teardown: stop containers, remove volumes, and reset the environment.
# Run from the repo root:
#   ./compose/teardown.sh
set -euo pipefail

# Compose file lives in compose/; point the CLI at it and the root .env.
export COMPOSE_FILE="${COMPOSE_FILE:-compose/docker-compose.yml}"
export COMPOSE_ENV_FILES="${COMPOSE_ENV_FILES:-.env}"

echo "=========================================="
echo "DBA Agent Talk Kit — Full Stack Teardown"
echo "=========================================="
echo ""

# Check if stack is running
if ! docker compose ps --services --filter "status=running" >/dev/null 2>&1; then
  echo "⚠️  No containers running. Nothing to tear down."
  exit 0
fi

echo "🛑 Stopping all containers..."
docker compose down --remove-orphans
echo "✓ Containers stopped"
echo ""

echo "🗑️  Removing volumes..."
docker compose down --volumes --remove-orphans
echo "✓ Volumes removed"
echo ""

echo "=========================================="
echo "✅ Stack Torn Down"
echo "=========================================="
echo ""
echo "All containers, volumes, and networks have been removed."
echo "To restart: ./compose/startup.sh"
echo ""
