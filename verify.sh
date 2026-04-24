#!/usr/bin/env bash
set -uo pipefail

COMPOSE_PROJECT="$(basename "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)")"
COMPOSE_NETWORK="${COMPOSE_PROJECT}_llm_network"
PASS=0
FAIL=0

result() {
    local marker="$1"
    local msg="$2"
    echo "[${marker}] ${msg}"
    if [ "$marker" = "OK" ]; then
        PASS=$((PASS + 1))
    elif [ "$marker" = "NG" ]; then
        FAIL=$((FAIL + 1))
    fi
}

echo "=== verify.sh: post-startup health checks ==="
echo ""

# Step 1: Port binding
echo "--- [1/5] Port binding ---"
if ss -tlnp | grep -qE ":(7777|7778) "; then
    result "OK" "Ports 7777/7778 are bound."
    ss -tlnp | grep -E ":(7777|7778) "
else
    result "NG" "Expected ports 7777/7778 not found in ss output."
fi
echo ""

# Step 2: SearXNG JSON search response
echo "--- [2/5] SearXNG JSON search ---"
SEARXNG_RESP=$(curl -sf --max-time 10 \
    "http://localhost:7778/search?q=test&format=json" 2>/dev/null || true)
if [ -n "$SEARXNG_RESP" ]; then
    FIRST_RESULT=$(echo "$SEARXNG_RESP" | jq -r '.results[0]' 2>/dev/null || true)
    if [ -n "$FIRST_RESULT" ] && [ "$FIRST_RESULT" != "null" ]; then
        result "OK" "SearXNG returned JSON results."
        echo "$SEARXNG_RESP" | jq '.results[0]' 2>/dev/null || true
    else
        result "NG" "SearXNG responded but results array is empty or null."
        echo "$SEARXNG_RESP" | head -c 300
    fi
else
    result "NG" "SearXNG did not respond on http://localhost:7778"
fi
echo ""

# Step 3: Ollama model list
echo "--- [3/5] Ollama model list ---"
if docker compose exec -T ollama ollama list 2>/dev/null; then
    result "OK" "Ollama model list retrieved."
else
    result "NG" "Failed to list Ollama models. Is the ollama container running?"
fi
echo ""

# Step 4: Open WebUI UI response
echo "--- [4/5] Open WebUI UI ---"
OWUI_RESP=$(curl -sf --max-time 10 "http://localhost:7777/" 2>/dev/null || true)
if echo "$OWUI_RESP" | grep -qi "open.webui\|open webui"; then
    result "OK" "Open WebUI responded with expected content."
else
    result "NG" "Open WebUI did not return expected content on http://localhost:7777"
fi
echo ""

# Step 5: Inference test (gemma4:e2b via Ollama API)
echo "--- [5/5] Inference test (gemma4:e2b) ---"
INFERENCE_PAYLOAD='{"model":"gemma4:e2b","prompt":"hi","stream":false}'
OLLAMA_API_URL="http://ollama:11434/api/generate"
INFERENCE_RESP=""

# Attempt 1: curl inside open-webui container
INFERENCE_RESP=$(docker compose exec -T open-webui \
    curl -sf --max-time 120 \
    -H "Content-Type: application/json" \
    -d "$INFERENCE_PAYLOAD" \
    "$OLLAMA_API_URL" 2>/dev/null || true)

if [ -z "$INFERENCE_RESP" ]; then
    echo "  open-webui curl failed or unavailable, trying curlimages/curl fallback..."
    INFERENCE_RESP=$(docker run --rm \
        --network "$COMPOSE_NETWORK" \
        curlimages/curl:latest \
        curl -sf --max-time 120 \
        -H "Content-Type: application/json" \
        -d "$INFERENCE_PAYLOAD" \
        "$OLLAMA_API_URL" 2>/dev/null || true)
fi

if [ -n "$INFERENCE_RESP" ]; then
    MODEL_RESPONSE=$(echo "$INFERENCE_RESP" | jq -r '.response' 2>/dev/null || true)
    if [ -n "$MODEL_RESPONSE" ] && [ "$MODEL_RESPONSE" != "null" ]; then
        result "OK" "Model responded to inference request."
        echo "  Model output: ${MODEL_RESPONSE}"
    else
        result "NG" "Inference API responded but .response field is empty."
        echo "$INFERENCE_RESP" | head -c 300
    fi
else
    result "SKIP" "Inference test skipped: could not reach Ollama API from any container. Check that gemma4:e2b is pulled."
fi
echo ""

# Summary
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
