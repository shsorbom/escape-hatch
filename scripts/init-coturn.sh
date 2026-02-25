#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COTURN_DIR="$PROJECT_ROOT/coturn"
ENV_FILE="$PROJECT_ROOT/.env"

echo "📁 Initializing coturn project structure..."

mkdir -p "$COTURN_DIR"

# -------------------------------------------------------------------
# Create coturn compose file
# -------------------------------------------------------------------

COMPOSE_FILE="$COTURN_DIR/compose.yml"

if [[ ! -f "$COMPOSE_FILE" ]]; then
cat > "$COMPOSE_FILE" <<'EOF'
services:
  coturn:
    image: coturn/coturn:4.6
    container_name: coturn
    restart: unless-stopped
    network_mode: host
    volumes:
      - ./turnserver.conf:/etc/coturn/turnserver.conf:ro
      - ../nginx/certs:/etc/ssl/certs:ro
    command: ["-c", "/etc/coturn/turnserver.conf"]
EOF
  echo "  ✔ Created coturn/compose.yml"
else
  echo "  ↷ Skipped existing coturn/compose.yml"
fi

# -------------------------------------------------------------------
# Create turnserver.conf template
# -------------------------------------------------------------------

CONF_FILE="$COTURN_DIR/turnserver.conf"

if [[ ! -f "$CONF_FILE" ]]; then
cat > "$CONF_FILE" <<'EOF'
# =====================================================
# Coturn Configuration (Template – Not Production Yet)
# =====================================================

# Listening ports
listening-port=3478
tls-listening-port=5349

# TODO: Replace with public IP before deployment
# external-ip=YOUR_PUBLIC_IP

# Realm (match MATRIX_SERVER_NAME)
realm=example.com
server-name=example.com

# Enable shared secret authentication (with Synapse)
use-auth-secret
static-auth-secret=CHANGE_ME_BEFORE_DEPLOYMENT

# Relay port range
min-port=49152
max-port=49200

# TLS certificates (mounted from nginx/certs)
cert=/etc/ssl/certs/fullchain.pem
pkey=/etc/ssl/certs/privkey.pem

# Security
no-multicast-peers
no-loopback-peers
no-cli
fingerprint

# Logging
simple-log
EOF
  echo "  ✔ Created coturn/turnserver.conf (template)"
else
  echo "  ↷ Skipped existing coturn/turnserver.conf"
fi

# -------------------------------------------------------------------
# Ensure TURN env stub exists
# -------------------------------------------------------------------

if [[ -f "$ENV_FILE" ]]; then
  if ! grep -q "TURN_SHARED_SECRET" "$ENV_FILE"; then
    echo "" >> "$ENV_FILE"
    echo "# === TURN (coturn) ===" >> "$ENV_FILE"
    echo "TURN_SHARED_SECRET=CHANGE_ME_BEFORE_DEPLOYMENT" >> "$ENV_FILE"
    echo "  ✔ Added TURN_SHARED_SECRET stub to .env"
  else
    echo "  ↷ TURN_SHARED_SECRET already present in .env"
  fi
else
  echo "  ⚠ No .env file found — skipping env stub"
fi

echo
echo "✅ Coturn project scaffolding complete."
echo "⚠ This is NOT ready for deployment."
echo
echo "Before deploying you must:"
echo "  • Set TURN_SHARED_SECRET in .env"
echo "  • Set external-ip in turnserver.conf"
echo "  • Replace realm/server-name"
echo "  • Add Synapse turn_uris + turn_shared_secret"
