#!/usr/bin/env bash
set -euo pipefail

echo "========================================="
echo "Project Escape Hatch - FIRST RUN SETUP"
echo "========================================="
echo

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

ENV_FILE=".env"
ENV_EXAMPLE=".env.example"
NGINX_CONF="nginx/conf/conf.d/escape-hatch.conf"
SYNAPSE_CONFIG="synapse/data/homeserver.yaml"
ELEMENT_CONFIG="element/config.json"
COTURN_CONFIG="coturn/turnserver.conf"
BOTAMUSIQUE_CONFIG_DIR="botamusique/config"
MUMBLE_INI="mumble/data/mumble-server.ini"

# --------------------------------------------------
# 1. DOMAIN INPUT
# --------------------------------------------------

if [[ -f "$ENV_FILE" ]]; then
    echo "ERROR: .env already exists."
    echo "This script is for first-time setup only."
    exit 1
fi

if [[ $# -ge 1 ]]; then
    DOMAIN="$1"
else
    read -rp "Enter your root domain (example.com): " DOMAIN
fi

if [[ -z "$DOMAIN" ]]; then
    echo "Domain cannot be empty."
    exit 1
fi

echo "Using domain: $DOMAIN"
echo

# --------------------------------------------------
# 1a. DISCOVER SUBDOMAINS FROM NGINX
# --------------------------------------------------

echo "Discovering subdomains from nginx config..."

mapfile -t SUBDOMAINS < <(
    grep -oE "[a-zA-Z0-9.-]+\.example\.com|example\.com" "$NGINX_CONF" \
    | sort -u
)

if [[ ${#SUBDOMAINS[@]} -eq 0 ]]; then
    echo "No subdomains found in nginx config."
    exit 1
fi

echo "Found:"
for s in "${SUBDOMAINS[@]}"; do
    echo "  - $s"
done
echo

# Replace example.com preserving subdomain prefixes
for s in "${SUBDOMAINS[@]}"; do
    NEW="${s/example.com/$DOMAIN}"
    sed -i "s/$s/$NEW/g" "$NGINX_CONF"
    sed -i "s/$s/$NEW/g" "$ELEMENT_CONFIG"
done

# Replace base domain everywhere else
grep -rl "example.com" . \
    --exclude-dir=.git \
    --exclude="$NGINX_CONF" \
    --exclude="$ELEMENT_CONFIG" \
    | xargs sed -i "s/example.com/$DOMAIN/g"

# --------------------------------------------------
# 2. GENERATE SECRETS
# --------------------------------------------------

echo "Generating secure secrets..."

rand_hex() { openssl rand -hex 32; }
rand_base64() { openssl rand -base64 48 | tr -d "=+/"; }

FRIEND_CODE="$(rand_base64)"
POSTGRES_PASSWORD="$(rand_base64)"
MUMBLE_PASSWORD="$(rand_base64)"
BOTAMUSIQUE_WEB_PASSWORD="$(rand_base64)"

SYNAPSE_REGISTRATION_SHARED_SECRET="$(rand_hex)"
SYNAPSE_MACAROON_SECRET_KEY="$(rand_hex)"
SYNAPSE_FORM_SECRET="$(rand_hex)"

TURN_SHARED_SECRET="$(rand_hex)"

# --------------------------------------------------
# 3. CREATE .env
# --------------------------------------------------

echo "Creating .env..."

cat > "$ENV_FILE" <<EOF
# === DOMAIN ===
DOMAIN=$DOMAIN

# === TIMEZONE ===
TZ=UTC

# === FRIEND CODE ===
FRIEND_CODE=$FRIEND_CODE

# === MATRIX / SYNAPSE ===
MATRIX_SERVER_NAME=$DOMAIN
POSTGRES_PASSWORD=$POSTGRES_PASSWORD

# === SYNAPSE SECRETS ===
SYNAPSE_REGISTRATION_SHARED_SECRET=$SYNAPSE_REGISTRATION_SHARED_SECRET
SYNAPSE_MACAROON_SECRET_KEY=$SYNAPSE_MACAROON_SECRET_KEY
SYNAPSE_FORM_SECRET=$SYNAPSE_FORM_SECRET

# === TURN (coturn) ===
TURN_SHARED_SECRET=$TURN_SHARED_SECRET

# === MUMBLE ===
MUMBLE_PASSWORD=$MUMBLE_PASSWORD

# === BOTAMUSIQUE ===
BOTAMUSIQUE_VERSION=0.9.2
BOTAMUSIQUE_WEB_PASSWORD=$BOTAMUSIQUE_WEB_PASSWORD
EOF

# --------------------------------------------------
# 4. UPDATE COTURN CONFIG
# --------------------------------------------------

echo "Configuring coturn..."

sed -i "s/realm=.*/realm=$DOMAIN/" "$COTURN_CONFIG"
sed -i "s/server-name=.*/server-name=$DOMAIN/" "$COTURN_CONFIG"
sed -i "s/static-auth-secret=.*/static-auth-secret=$TURN_SHARED_SECRET/" "$COTURN_CONFIG"

# --------------------------------------------------
# 5. WIRE COTURN INTO SYNAPSE
# --------------------------------------------------

echo "Adding TURN settings to Synapse..."

cat >> "$SYNAPSE_CONFIG" <<EOF

# TURN integration
turn_uris:
  - "turn:$DOMAIN:3478?transport=udp"
  - "turn:$DOMAIN:3478?transport=tcp"
turn_shared_secret: "$TURN_SHARED_SECRET"
turn_user_lifetime: 86400000
turn_allow_guests: false
EOF

# --------------------------------------------------
# 6. WIRE COTURN INTO ELEMENT
# --------------------------------------------------

echo "Enabling TURN in Element..."

jq ". + {
  \"voip\": {
    \"turnServers\": [{
      \"urls\": [
        \"turn:$DOMAIN:3478?transport=udp\",
        \"turn:$DOMAIN:3478?transport=tcp\"
      ]
    }]
  }
}" "$ELEMENT_CONFIG" > tmp.json && mv tmp.json "$ELEMENT_CONFIG"

# --------------------------------------------------
# 7. CONFIGURE MUMBLE SUPERUSER
# --------------------------------------------------

echo "Mumble superuser password set via env."

# Already wired via compose → no extra action needed

# --------------------------------------------------
# 8. GENERATE BOTAMUSIQUE CONFIG
# --------------------------------------------------

echo "Generating Botamusique config..."

mkdir -p "$BOTAMUSIQUE_CONFIG_DIR"

cat > "$BOTAMUSIQUE_CONFIG_DIR/config.ini" <<EOF
[bot]
server = mumble
port = 64738
username = MusicBot
password =
channel =
web_password = $BOTAMUSIQUE_WEB_PASSWORD

[connection]
reconnect = true
EOF

# --------------------------------------------------
# 9. CREATE SYNAPSE DATA DIR
# --------------------------------------------------

mkdir -p synapse/data synapse/db mumble/data botamusique/config

echo
echo "========================================="
echo "Bootstrap Complete"
echo "========================================="
echo
echo "Domain:              $DOMAIN"
echo "Friend Code:         $FRIEND_CODE"
echo "Mumble Admin Pass:   $MUMBLE_PASSWORD"
echo
echo "Next steps:"
echo "  1. Point DNS to this server"
echo "  2. Run ./scripts/letsencrypt-setup.sh"
echo "  3. Run ./scripts/start.sh"
echo
