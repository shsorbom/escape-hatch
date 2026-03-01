#!/usr/bin/env bash
set -euo pipefail

echo "======================================="
echo "Escape Hatch - Standalone Certificate"
echo "======================================="
echo

# --------------------------------------------------
# Resolve project root
# --------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$PROJECT_ROOT/self-hosted-chat/.env"

if [[ ! -f "$ENV_FILE" ]]; then
    echo "ERROR: .env file not found at:"
    echo "  $ENV_FILE"
    exit 1
fi

# --------------------------------------------------
# Load environment variables
# --------------------------------------------------
set -a
source "$ENV_FILE"
set +a

# --------------------------------------------------
# Validate required variables
# --------------------------------------------------
: "${DOMAIN:?DOMAIN not set in .env}"
: "${EMAIL:?EMAIL not set in .env}"

PROXY_CONTAINER="nginx"
NGINX_CONF_DIR="$PROJECT_ROOT/self-hosted-chat/nginx/conf/conf.d"

# --------------------------------------------------
# Detect Docker availability
# --------------------------------------------------
DOCKER_AVAILABLE=false

if command -v docker >/dev/null 2>&1; then
    if docker info >/dev/null 2>&1; then
        DOCKER_AVAILABLE=true
    fi
fi

NGINX_WAS_RUNNING=false

# --------------------------------------------------
# Restore handler (ALWAYS runs on exit)
# --------------------------------------------------
restore_nginx() {
    if [ "$DOCKER_AVAILABLE" = true ] && [ "$NGINX_WAS_RUNNING" = true ]; then
        echo
        echo "Restoring nginx container..."
        docker start "$PROXY_CONTAINER" >/dev/null 2>&1 || true
        echo "Nginx restored."
    fi
}

trap restore_nginx EXIT

# --------------------------------------------------
# Stop nginx container if running
# --------------------------------------------------
if [ "$DOCKER_AVAILABLE" = true ]; then
    if docker ps --format '{{.Names}}' | grep -q "^${PROXY_CONTAINER}$"; then
        echo "Nginx container is running."
        echo "Stopping nginx temporarily..."
        docker stop "$PROXY_CONTAINER"
        NGINX_WAS_RUNNING=true
    fi
fi

# --------------------------------------------------
# Ensure port 80 is free
# --------------------------------------------------
if ss -ltn | grep -q ':80 '; then
    echo "ERROR: Port 80 is still in use."
    echo "Cannot run certbot in standalone mode."
    exit 1
fi

# --------------------------------------------------
# Discover domains from nginx config
# --------------------------------------------------
if [ ! -d "$NGINX_CONF_DIR" ]; then
    echo "ERROR: Nginx config directory not found:"
    echo "  $NGINX_CONF_DIR"
    exit 1
fi

echo "Discovering domains..."

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
mapfile -t UNIQUE_DOMAINS < <(printf "%s\n" "${DOMAINS[@]}" | sort -u)

if [ ${#UNIQUE_DOMAINS[@]} -eq 0 ]; then
    echo "ERROR: No matching domains discovered."
    exit 1
fi

echo
echo "Domains discovered:"
for d in "${UNIQUE_DOMAINS[@]}"; do
    echo " - $d"
done
echo

# --------------------------------------------------
# Build certbot domain flags
# --------------------------------------------------
CERT_ARGS=()
for d in "${UNIQUE_DOMAINS[@]}"; do
    CERT_ARGS+=("-d" "$d")
done

# --------------------------------------------------
# Run certbot in standalone mode
# --------------------------------------------------
echo "Requesting certificate using standalone mode..."

certbot certonly \
    --standalone \
    --preferred-challenges http \
    --non-interactive \
    --agree-tos \
    --email "$EMAIL" \
    --expand \
    --rsa-key-size 4096 \
    "${CERT_ARGS[@]}"

echo
echo "Certificate operation complete."
echo "Done."
