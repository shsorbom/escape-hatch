#!/usr/bin/env bash
set -euo pipefail

echo "========================================="
echo "Escape Hatch - Webroot Migration"
echo "========================================="
echo

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
STACK_ROOT="$REPO_ROOT/self-hosted-chat"

TIMESTAMP=$(date +%Y%m%d%H%M%S)
BACKUP_DIR="$STACK_ROOT/webroot-migration-backup-$TIMESTAMP"

echo "Creating backup in:"
echo "  $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

backup() {
  local file="$1"
  if [[ -f "$STACK_ROOT/$file" ]]; then
    mkdir -p "$BACKUP_DIR/$(dirname "$file")"
    cp "$STACK_ROOT/$file" "$BACKUP_DIR/$file"
  fi
}

echo
echo "Backing up stack files..."

backup "docker-compose.yml"
backup "nginx/conf/conf.d/escape-hatch.conf"

echo
echo "Creating cert directories..."
mkdir -p "$STACK_ROOT/nginx/certs"
mkdir -p "$STACK_ROOT/nginx/acme-challenge"
mkdir -p "$STACK_ROOT/certbot"

echo
echo "Patching nginx compose volumes..."

COMPOSE_FILE="$STACK_ROOT/docker-compose.yml"

# Remove host-level mounts
sed -i '/\/etc\/letsencrypt/d' "$COMPOSE_FILE"
sed -i '/\/var\/www\/letsencrypt/d' "$COMPOSE_FILE"

# Add new mounts if missing
if ! grep -q "nginx/certs" "$COMPOSE_FILE"; then
  sed -i '/nginx\/html/a\      - ./nginx/certs:/etc/letsencrypt\n      - ./nginx/acme-challenge:/var/www/certbot' "$COMPOSE_FILE"
fi

echo
echo "Ensuring ACME challenge block exists..."

NGINX_CONF="$STACK_ROOT/nginx/conf/conf.d/escape-hatch.conf"

if ! grep -q "acme-challenge" "$NGINX_CONF"; then
  sed -i '/listen 80;/a\
\
    location /.well-known/acme-challenge/ {\
        root /var/www/certbot;\
    }\
' "$NGINX_CONF"
fi

echo
echo "Creating certbot compose file..."

cat > "$STACK_ROOT/certbot/compose.yml" <<'EOF'
services:
  certbot:
    image: certbot/certbot:latest
    container_name: certbot
    volumes:
      - ../nginx/certs:/etc/letsencrypt
      - ../nginx/acme-challenge:/var/www/certbot
    entrypoint: ""
EOF

echo
echo "Patching start/stop scripts..."

patch_script() {
  local file="$1"
  if ! grep -q "certbot/compose.yml" "$file"; then
    sed -i '/coturn\/compose.yml/a\  -f certbot/compose.yml' "$file"
  fi
}

patch_script "$REPO_ROOT/scripts/start.sh"
patch_script "$REPO_ROOT/scripts/stop.sh"

echo
echo "Migration complete."
echo
echo "Restart stack:"
echo "  ./scripts/stop.sh"
echo "  ./scripts/start.sh"
echo
echo "Certificates will now live in:"
echo "  self-hosted-chat/nginx/certs"
echo
echo "Backup stored in:"
echo "  $BACKUP_DIR"
