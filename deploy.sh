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

# Get current git SHA as the new version tag
NEW_VERSION=$(git -C "$PROJECT_DIR" rev-parse --short HEAD)
log "Starting deployment of version: $NEW_VERSION"

# Save current version as previous (for rollback)
if [ -f "$STATE_FILE" ]; then
    cp "$STATE_FILE" "$PREVIOUS_STATE_FILE"
    log "Previous version recorded: $(cat "$PREVIOUS_STATE_FILE")"
fi

# Build the app image with the new version tag
log "Building image: observability-lab-app:$NEW_VERSION"
docker build -t "observability-lab-app:$NEW_VERSION" "$PROJECT_DIR/app"
docker tag "observability-lab-app:$NEW_VERSION" "observability-lab-app:latest"

# Bring up the stack
log "Deploying stack..."
cd "$PROJECT_DIR"
docker compose up -d --build

# Health check
log "Waiting for application to be healthy..."
for i in {1..30}; do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5000/health || echo "000")
    if [ "$HTTP_CODE" = "200" ]; then
        log "Health check passed (HTTP 200)"
        echo "$NEW_VERSION" > "$STATE_FILE"
        log "Deployment successful. Active version: $NEW_VERSION"
        exit 0
    fi
    log "Waiting for app... ($i/30)"
    sleep 2
done

log "Health check FAILED. Consider running rollback.sh"
exit 1

