#!/usr/bin/env bash
set -euo pipefail

echo "========================================="
echo "Project Escape Hatch - Domain Migration"
echo "========================================="
echo

if [[ $# -ne 2 ]]; then
    echo "Usage:"
    echo "  ./scripts/change-domain.sh old-domain.com new-domain.com"
    exit 1
fi

OLD_DOMAIN="$1"
NEW_DOMAIN="$2"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT/self-hosted-chat"

echo "Old domain: $OLD_DOMAIN"
echo "New domain: $NEW_DOMAIN"
echo
read -p "Proceed with replacement? (yes/no): " CONFIRM

if [[ "$CONFIRM" != "yes" ]]; then
    echo "Aborted."
    exit 1
fi

TIMESTAMP=$(date +%Y%m%d%H%M%S)
BACKUP_DIR="domain-backup-$TIMESTAMP"

echo
echo "Creating backup in $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

FILES=(
  ".env"
  "synapse/data/homeserver.yaml"
  "element/config.json"
  "nginx/conf/conf.d/escape-hatch.conf"
)

for file in "${FILES[@]}"; do
    if [[ -f "$file" ]]; then
        mkdir -p "$BACKUP_DIR/$(dirname "$file")"
        cp "$file" "$BACKUP_DIR/$file"
    fi
done

echo
echo "Replacing domain references..."

# Safe replace function
replace_domain() {
    local file="$1"

    if [[ -f "$file" ]]; then
        sed -i "s/$OLD_DOMAIN/$NEW_DOMAIN/g" "$file"
        echo "Updated: $file"
    fi
}

# Update main files
replace_domain ".env"
replace_domain "synapse/data/homeserver.yaml"
replace_domain "element/config.json"
replace_domain "nginx/conf/conf.d/escape-hatch.conf"

echo
echo "Updating signing key filename reference..."

OLD_KEY="synapse/data/$OLD_DOMAIN.signing.key"
NEW_KEY="synapse/data/$NEW_DOMAIN.signing.key"

if [[ -f "$OLD_KEY" ]]; then
    mv "$OLD_KEY" "$NEW_KEY"
    echo "Renamed signing key:"
    echo "  $OLD_KEY → $NEW_KEY"
else
    echo "No signing key found to rename (may generate new one on restart)"
fi

echo
echo "Domain migration complete."
echo
echo "IMPORTANT NEXT STEPS:"
echo "1. Update DNS records for $NEW_DOMAIN"
echo "2. Regenerate Let's Encrypt certificates"
echo "3. Restart stack:"
echo "     ./scripts/restart.sh"
echo
echo "Backup stored in:"
echo "  $BACKUP_DIR"
