#!/usr/bin/env bash
set -euo pipefail

echo "========================================="
echo "Project Escape Hatch - START"
echo "========================================="
echo

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT/self-hosted-chat"

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

# Ensure Docker is running
if ! docker info > /dev/null 2>&1; then
  echo "Docker is not running. Attempting to start..."
  sudo systemctl start docker
fi

echo "Validating configuration..."
docker compose -p "$STACK_NAME" "${COMPOSE_FILES[@]}" config > /dev/null

echo "Pulling images..."
docker compose -p "$STACK_NAME" "${COMPOSE_FILES[@]}" pull

echo "Starting services..."
docker compose -p "$STACK_NAME" "${COMPOSE_FILES[@]}" up -d

echo
echo "All services started successfully."
