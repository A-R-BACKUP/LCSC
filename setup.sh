#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

check_port() {
    local port="$1"
    if ss -tlnp | grep -q ":${port} "; then
        echo "[NG] Port ${port} is already in use. Aborting."
        ss -tlnp | grep ":${port} "
        exit 1
    fi
    echo "[OK] Port ${port} is free."
}

echo "--- Checking required ports ---"
check_port 7777
check_port 7778

echo ""
echo "--- Generating SEARXNG_SECRET ---"
SECRET="$(openssl rand -hex 32)"
if [ -z "$SECRET" ]; then
    echo "[NG] Failed to generate secret with openssl."
    exit 1
fi
echo "[OK] Secret generated."

echo ""
echo "--- Writing .env ---"
ENV_FILE="${SCRIPT_DIR}/.env"
printf "SEARXNG_SECRET=%s\n" "$SECRET" > "$ENV_FILE"
if [ -f "$ENV_FILE" ]; then
    echo "[OK] .env written to ${ENV_FILE}"
else
    echo "[NG] Failed to write .env"
    exit 1
fi

echo ""
echo "--- Preparing searxng/settings.yml ---"
EXAMPLE_FILE="${SCRIPT_DIR}/searxng/settings.yml.example"
TARGET_FILE="${SCRIPT_DIR}/searxng/settings.yml"

if [ ! -f "$EXAMPLE_FILE" ]; then
    echo "[NG] Template not found: ${EXAMPLE_FILE}"
    exit 1
fi

cp "$EXAMPLE_FILE" "$TARGET_FILE"
if [ ! -f "$TARGET_FILE" ]; then
    echo "[NG] Failed to copy settings.yml.example to settings.yml"
    exit 1
fi
echo "[OK] settings.yml created from template."

sed -i "s/__SEARXNG_SECRET_PLACEHOLDER__/${SECRET}/" "$TARGET_FILE"
if grep -q "__SEARXNG_SECRET_PLACEHOLDER__" "$TARGET_FILE"; then
    echo "[NG] Placeholder was not replaced in settings.yml"
    exit 1
fi
echo "[OK] Secret injected into settings.yml."

echo ""
echo "--- Setup complete ---"
echo "Next steps:"
echo "  1. docker compose up -d"
echo "  2. docker compose exec ollama ollama pull gemma4:e2b"
echo "  3. ./verify.sh"
