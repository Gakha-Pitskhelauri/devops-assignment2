#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

echo "==> Observability Lab bootstrap"

# 1. Check Docker
if ! command -v docker > /dev/null 2>&1; then
    echo "ERROR: Docker is not installed. Install Docker Desktop or Docker Engine first."
    exit 1
fi

if ! docker info > /dev/null 2>&1; then
    echo "ERROR: Docker daemon is not running. Start Docker Desktop and try again."
    exit 1
fi
echo "  Docker OK"

# 2. Check docker compose
if ! docker compose version > /dev/null 2>&1; then
    echo "ERROR: docker compose plugin not available."
    exit 1
fi
echo "  Docker Compose OK"

# 3. Ensure .env exists
if [ ! -f .env ]; then
    if [ -f .env.example ]; then
        cp .env.example .env
        echo "  Created .env from .env.example"
    fi
fi

# 4. Create logs directory
mkdir -p logs
echo "  logs/ ready"

# 5. Build and start stack
echo "==> Building and starting stack..."
docker compose up -d --build

# 6. Wait for Flask app health
echo "==> Waiting for Flask app to be healthy..."
for i in {1..30}; do
    if curl -fs http://localhost:5000/health > /dev/null 2>&1; then
        echo "  App is healthy"
        break
    fi
    echo "  Waiting... ($i/30)"
    sleep 2
    if [ "$i" = "30" ]; then
        echo "ERROR: App did not become healthy in time"
        docker compose logs app --tail=30
        exit 1
    fi
done

echo ""
echo "==> Setup complete!"
echo ""
echo "  Flask app  : http://localhost:5000"
echo "  Prometheus : http://localhost:9090"
echo "  Grafana    : http://localhost:3000  (login: admin / password from .env)"
echo "  Loki       : http://localhost:3100"

