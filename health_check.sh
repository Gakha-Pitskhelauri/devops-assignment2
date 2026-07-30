#!/bin/bash

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="$PROJECT_DIR/logs"
LOG_FILE="$LOG_DIR/health.log"
INTERVAL=30

mkdir -p "$LOG_DIR"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "Health monitor started. Checking every ${INTERVAL}s. Press Ctrl+C to stop."
log "----------------------------------------"

while true; do
    HTTP_CODE=$(curl -s -o /tmp/health_response.json -w "%{http_code}" http://localhost:5000/health 2>/dev/null || echo "000")
    RESPONSE=$(cat /tmp/health_response.json 2>/dev/null || echo "no response")

    if [ "$HTTP_CODE" = "200" ]; then
        log "[UP]   http_code=$HTTP_CODE response=$RESPONSE"
    else
        log "[DOWN] http_code=$HTTP_CODE"
    fi

    sleep $INTERVAL
done

