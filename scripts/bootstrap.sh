#!/usr/bin/env bash
set -euo pipefail

echo "========================================="
echo "Escape Hatch - First Time Bootstrap"
echo "========================================="
echo

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
STACK_ROOT="$REPO_ROOT/self-hosted-chat"

ENV_FILE="$STACK_ROOT/.env"
ENV_EXAMPLE="$STACK_ROOT/.env.example"

NGINX_CONF="$STACK_ROOT/nginx/conf/conf.d/escape-hatch.conf"
HOMESERVER="$STACK_ROOT/synapse/data/homeserver.yaml"
ELEMENT_CONFIG="$STACK_ROOT/element/config.json"

BOTAMUSIQUE_DIR="$STACK_ROOT/botamusique/data"
BOTAMUSIQUE_CONFIG="$BOTAMUSIQUE_DIR/config.ini"

# ------------------------------------------------------------------
# Docker Check
# ------------------------------------------------------------------

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker not installed."
  echo "Install Docker first."
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "Docker Compose v2 plugin missing."
  exit 1
fi

echo "Docker OK."
echo

# ------------------------------------------------------------------
# Prevent accidental overwrite
# ------------------------------------------------------------------

if [[ -f "$ENV_FILE" ]]; then
  echo ".env already exists."
  read -p "Overwrite existing configuration? (yes/no): " CONFIRM
  if [[ "$CONFIRM" != "yes" ]]; then
    echo "Aborting."
    exit 1
  fi
fi

# ------------------------------------------------------------------
# Ask for domain
# ------------------------------------------------------------------

read -p "Enter your root domain (example.com): " DOMAIN

if [[ -z "$DOMAIN" ]]; then
  echo "Domain required."
  exit 1
fi

# ------------------------------------------------------------------
# Secret generation
# ------------------------------------------------------------------

gen_secret() {
  openssl rand -hex 32
}

FRIEND_CODE=$(gen_secret)
POSTGRES_PASSWORD=$(gen_secret)
REG_SECRET=$(gen_secret)
MACAROON_SECRET=$(gen_secret)
FORM_SECRET=$(gen_secret)
BOT_WEB_PASS=$(gen_secret)

# ------------------------------------------------------------------
# Create .env
# ------------------------------------------------------------------

if [[ ! -f "$ENV_EXAMPLE" ]]; then
  echo ".env.example missing."
  exit 1
fi

cp "$ENV_EXAMPLE" "$ENV_FILE"

sed -i "s/example.com/$DOMAIN/g" "$ENV_FILE"
sed -i "s/change-me-to-a-long-random-string/$FRIEND_CODE/" "$ENV_FILE"
sed -i "s/change-me/$POSTGRES_PASSWORD/" "$ENV_FILE"
sed -i "0,/PUT_LONG_RANDOM_HEX_HERE/s//$REG_SECRET/" "$ENV_FILE"
sed -i "0,/PUT_LONG_RANDOM_HEX_HERE/s//$MACAROON_SECRET/" "$ENV_FILE"
sed -i "0,/PUT_LONG_RANDOM_HEX_HERE/s//$FORM_SECRET/" "$ENV_FILE"
sed -i "s/BOTAMUSIQUE_WEB_PASSWORD=.*/BOTAMUSIQUE_WEB_PASSWORD=$BOT_WEB_PASS/" "$ENV_FILE"

echo ".env created."

# ------------------------------------------------------------------
# Replace domain in config files
# ------------------------------------------------------------------

echo "Updating configuration files..."

if [[ -f "$NGINX_CONF" ]]; then
  sed -i "s/example.com/$DOMAIN/g" "$NGINX_CONF"
fi

if [[ -f "$HOMESERVER" ]]; then
  sed -i "s/example.com/$DOMAIN/g" "$HOMESERVER"
fi

if [[ -f "$ELEMENT_CONFIG" ]]; then
  sed -i "s/example.com/$DOMAIN/g" "$ELEMENT_CONFIG"
fi

# ------------------------------------------------------------------
# Rename signing key if needed
# ------------------------------------------------------------------

OLD_KEY="$STACK_ROOT/synapse/data/example.com.signing.key"
NEW_KEY="$STACK_ROOT/synapse/data/$DOMAIN.signing.key"

if [[ -f "$OLD_KEY" ]]; then
  mv "$OLD_KEY" "$NEW_KEY"
fi

# ------------------------------------------------------------------
# Generate Botamusique config
# ------------------------------------------------------------------

echo "Generating Botamusique config..."

mkdir -p "$BOTAMUSIQUE_DIR"

cat > "$BOTAMUSIQUE_CONFIG" <<EOF
[bot]
name = Botamusique
comment = Music bot
channel = Root
autoconnect = true
version = 0.0.0

[server]
host = mumble
port = 64738
username = Botamusique
password = $FRIEND_CODE

[webinterface]
enabled = true
host = 0.0.0.0
port = 8181

[media]
volume = 0.25

[update]
enabled = false
EOF

chmod 600 "$BOTAMUSIQUE_CONFIG"

echo "Botamusique config created."

# ------------------------------------------------------------------
# Completion Output
# ------------------------------------------------------------------

echo
echo "========================================="
echo "Bootstrap Complete"
echo "========================================="
echo
echo "DNS records required:"
echo
echo "  $DOMAIN"
echo "  matrix.$DOMAIN"
echo "  element.$DOMAIN"
echo "  call.$DOMAIN"
echo
echo "Next step:"
echo
echo "  ./scripts/start.sh"
echo
echo "Friend Code (Mumble password):"
echo "$FRIEND_CODE"
echo
echo "Store this securely."
echo
