#!/usr/bin/env bash

echo "========================================="
echo "Project Escape Hatch - Config Audit"
echo "========================================="
echo

ROOT_DIR="${1:-.}"

MAX_SIZE=$((500 * 1024))  # 500 KB

find "$ROOT_DIR" \
  -type f \
  ! -path "*/.git/*" \
  ! -path "*/node_modules/*" \
  ! -path "*/.cache/*" \
  ! -name "*.log" \
  ! -name "*.db" \
  ! -name "*.sqlite*" \
  ! -name "*.pem" \
  ! -name "*.key" \
  ! -name "*.crt" \
  | while read -r file; do

    size=$(stat -c%s "$file" 2>/dev/null)

    if [[ "$size" -gt "$MAX_SIZE" ]]; then
        echo "---- Skipping large file: $file ($size bytes)"
        continue
    fi

    echo
    echo "========================================="
    echo "FILE: $file"
    echo "========================================="
    cat "$file"
    echo
done
