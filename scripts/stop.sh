#!/usr/bin/env bash
set -euo pipefail

echo "========================================="
echo "Project Escape Hatch - STOP"
echo "========================================="
echo

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

STACK_NAME="escape-hatch"

COMPOSE_FILES=(
  -f docker-compose.yml
  -f synapse/compose.yml
  -f element/compose.yml
  -f element-call/compose.yml
  -f mumble/compose.yml
  -f botamusique/compose.yml
  -f website/compose.yml
  -f coturn/compose.yml
)

echo "Stopping services..."
docker compose -p "$STACK_NAME" "${COMPOSE_FILES[@]}" down

echo
echo "All services stopped."
