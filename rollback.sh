#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="$PROJECT_DIR/logs"
mkdir -p "$LOG_DIR"
DEPLOY_LOG="$LOG_DIR/deploy.log"
STATE_FILE="$PROJECT_DIR/.current-version"
PREVIOUS_STATE_FILE="$PROJECT_DIR/.previous-version"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$DEPLOY_LOG"
}

if [ ! -f "$PREVIOUS_STATE_FILE" ]; then
    log "No previous version recorded. Cannot roll back."
    exit 1
fi

PREVIOUS_VERSION=$(cat "$PREVIOUS_STATE_FILE")
log "Rolling back to version: $PREVIOUS_VERSION"

# Check the previous image still exists locally
if ! docker image inspect "observability-lab-app:$PREVIOUS_VERSION" > /dev/null 2>&1; then
    log "Previous image observability-lab-app:$PREVIOUS_VERSION not found. Cannot roll back."
    exit 1
fi

# Retag previous as latest
docker tag "observability-lab-app:$PREVIOUS_VERSION" "observability-lab-app:latest"

# Restart the app container with the retagged image
cd "$PROJECT_DIR"
docker compose up -d app

# Health check
log "Waiting for app to be healthy after rollback..."
for i in {1..30}; do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5000/health || echo "000")
    if [ "$HTTP_CODE" = "200" ]; then
        log "Rollback health check passed"
        echo "$PREVIOUS_VERSION" > "$STATE_FILE"
        log "Rollback successful. Active version: $PREVIOUS_VERSION"
        exit 0
    fi
    log "Waiting for app... ($i/30)"
    sleep 2
done

log "Rollback FAILED health check"
exit 1

