#!/usr/bin/env bash
set -euo pipefail

# Load environment
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

DOMAIN="${MATRIX_SERVER_NAME}"
EMAIL="admin@${DOMAIN}"
NGINX_CONF_DIR="./nginx/conf/conf.d"
PROXY_CONTAINER="nginx"

echo "======================================="
echo "Escape Hatch - Auto Subdomain Discovery"
echo "======================================="
echo

# --------------------------------------------------
# Graceful Docker check
# --------------------------------------------------
if ! command -v docker >/dev/null 2>&1; then
  echo "Docker not installed. Exiting."
  exit 0
fi

if ! docker info >/dev/null 2>&1; then
  echo "Docker daemon not running. Exiting."
  exit 0
fi

# --------------------------------------------------
# Discover domains from nginx configs
# --------------------------------------------------

echo "Discovering domains from nginx configs..."

if [ ! -d "$NGINX_CONF_DIR" ]; then
  echo "Nginx config directory not found. Exiting."
  exit 0
fi

DOMAINS=()

while IFS= read -r line; do
  for name in $line; do
    clean=$(echo "$name" | tr -d ';')
    if [[ "$clean" == *".$DOMAIN" || "$clean" == "$DOMAIN" ]]; then
      DOMAINS+=("$clean")
    fi
  done
done < <(grep -h "server_name" "$NGINX_CONF_DIR"/*.conf 2>/dev/null)

# Remove duplicates
UNIQUE_DOMAINS=($(printf "%s\n" "${DOMAINS[@]}" | sort -u))

if [ ${#UNIQUE_DOMAINS[@]} -eq 0 ]; then
  echo "No matching domains found."
  exit 0
fi

echo
echo "Domains discovered:"
for d in "${UNIQUE_DOMAINS[@]}"; do
  echo " - $d"
done
echo

# --------------------------------------------------
# Build certbot -d flags
# --------------------------------------------------

CERT_ARGS=()
for d in "${UNIQUE_DOMAINS[@]}"; do
  CERT_ARGS+=("-d" "$d")
done

# --------------------------------------------------
# Request or expand certificate
# --------------------------------------------------

certbot certonly \
  --webroot \
  --webroot-path "$WEBROOT" \
  --expand \
  "${CERT_ARGS[@]}" \
  --email "$EMAIL" \
  --agree-tos \
  --non-interactive \
  --rsa-key-size 4096

echo
echo "Certificate updated."

# --------------------------------------------------
# Reload nginx container if running
# --------------------------------------------------

if docker ps --format '{{.Names}}' | grep -q "^${PROXY_CONTAINER}$"; then
  echo "Reloading nginx..."
  docker kill -s HUP "$PROXY_CONTAINER"
else
  echo "Nginx container not running. Skipping reload."
fi

echo
echo "Done."
