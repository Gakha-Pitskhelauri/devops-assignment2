# DevOps Observability Lab

A containerized Python application with a full observability stack (metrics, logs, dashboards, alerting), CI/CD pipelines, automated security scanning, infrastructure-as-code, and deployment automation. Runs locally with a single command and no paid services.

This project extends earlier coursework — the observability stack and the midterm's CI/CD, IaC, and deployment work — unified and hardened for the final project.

## Architecture

Two data flows, both surfaced through Grafana:

```
                          docker-compose.yml

   +-----------+   GET /metrics (every 15s)   +--------------+
   | Flask app | <--------- scrape ---------- |  Prometheus  |
   |  :5000    |                              |  + alerts    |
   +-----+-----+                              +------+-------+
         | JSON logs -> stdout                       | PromQL
         v                                           v
   Docker json-file driver                      +---------+
         | Docker socket discovery              | Grafana |
         v                                       +----+----+
     +----------+       HTTP push       +------+      | LogQL
     | Promtail | -------------------> | Loki |-------+
     +----------+                       +------+
```

- **Metrics (pull):** Prometheus scrapes the app's `/metrics` every 15s and evaluates alert rules. Grafana queries Prometheus.
- **Logs (push):** the app writes JSON logs to stdout; Promtail discovers the container via the Docker socket, labels and parses them, and pushes to Loki. Grafana queries Loki.

## Tech Stack

| Layer | Tool |
|---|---|
| Application | Flask 3 + `prometheus-client` |
| Metrics | Prometheus |
| Log collection | Promtail |
| Log storage | Loki |
| Visualization & alerting | Grafana |
| Orchestration | Docker Compose |
| CI/CD | GitHub Actions |
| Infrastructure as Code | Ansible + Docker Compose |
| Security scanning | pip-audit, Trivy, gitleaks, hadolint, Checkov |
| Testing / linting | pytest, flake8 |

## Environment Setup

Prerequisite: Docker and Docker Compose installed and running.

Single-command bootstrap:

```bash
git clone <this-repo>
cd observability-lab
./setup.sh
```

`setup.sh` verifies Docker, creates `.env` from `.env.example`, brings up the stack, and waits until the app is healthy.

Alternatives:

```bash
ansible-playbook -i inventory.ini setup.yml   # Ansible (IaC)
docker compose up -d                          # raw compose
```

Configuration is externalized to a git-ignored `.env` (only `.env.example` is committed). Grafana datasources and dashboards are provisioned as code, so nothing needs manual setup in the UI.

Services once up:

| Service | URL | Credentials |
|---|---|---|
| Flask app | http://localhost:5000 | — |
| Health check | http://localhost:5000/health | — |
| Metrics | http://localhost:5000/metrics | — |
| Prometheus | http://localhost:9090 | — |
| Grafana | http://localhost:3000 | `admin` / from `.env` |
| Loki | http://localhost:3100 | — |

Stop everything: `docker compose down`

## Monitoring and Logging

**Monitoring:** Prometheus (`prometheus/prometheus.yml`) scrapes the app at `app:5000` every 15 seconds using a pull model, and labels all metrics with `job="flask-app"`.

**Logging:** the app emits structured JSON logs to stdout. Promtail (`promtail/promtail-config.yml`) discovers the container through the Docker socket, labels the logs `job="flask-app"`, parses the JSON, and pushes to Loki. Loki (`loki/loki-config.yml`) indexes only the labels and stores content as compressed chunks.

**Visualization:** Grafana queries both Prometheus and Loki through one UI, with a provisioned dashboard (requests + errors). View logs via Grafana → Explore → Loki → `{job="flask-app"}`.

Custom metrics: `app_requests_total{method, endpoint}` and `app_errors_total`.

## Alerting

Two critical alerts in `prometheus/alert_rules.yml`:

- **HighErrorRate** — fires when `increase(app_errors_total[1m]) > 5` (more than 5 errors in a minute).
- **ServiceDown** — fires when `up{job="flask-app"} == 0` for 1 minute (Prometheus can't scrape the app).

Trigger the error alert:

```bash
for i in {1..10}; do curl -s http://localhost:5000/error > /dev/null; done
```

Then check http://localhost:9090/alerts or Grafana → Alerting.

## Deployment Workflow

The deployment target is the local Docker Compose stack; the same commands work on any Docker host.

```bash
./deploy.sh        # tag image by commit SHA, deploy, verify /health, record version
./rollback.sh      # revert to the previously recorded version
./health_check.sh  # continuous /health monitoring, logs to logs/health.log
```

`deploy.sh` versions each release by git SHA and records the previous version so `rollback.sh` can revert. The new version is only recorded after the health check passes.

## CI/CD Pipeline

**CI** (`.github/workflows/ci.yml`) runs on every push to `main`/`dev` and PRs to `main`, in four sequential stages: **lint** (flake8) → **test** (pytest) → **build** (Docker image, saved as artifact) → **smoke-test** (spins up the full stack, verifies endpoints, checks Prometheus is scraping and Loki is ready, then tears down).

**CD** is handled by `deploy.sh`, triggered manually — Continuous Delivery, with `rollback.sh` for reverts.

## Security Implementation

`.github/workflows/security.yml` runs five scanners in parallel on every push:

| Scanner | Scans |
|---|---|
| pip-audit | Python dependencies (CVEs) |
| Trivy | Docker image (OS + library CVEs) |
| gitleaks | Git history for committed secrets |
| hadolint | Dockerfile best practices |
| Checkov | IaC / config misconfigurations |

Secrets are externalized to a git-ignored `.env`; only `.env.example` is committed, and the Grafana password is injected as an environment variable.

## Reliability Improvements

- **SLO** (`docs/SLO.md`) — 99.5% availability target with an error budget.
- **Runbook** (`docs/RUNBOOK.md`) — per-alert incident response playbooks.
- **Second alert** — `ServiceDown` added alongside `HighErrorRate`.
- **Rollback** — `rollback.sh` using SHA-tagged images.
- **Health monitoring** — `health_check.sh`, plus health verification in `deploy.sh` and the CI smoke test.

## Project Structure

```
.
├── .github/workflows/
│   ├── ci.yml              # lint -> test -> build -> smoke-test
│   └── security.yml        # pip-audit, Trivy, gitleaks, hadolint, Checkov
├── app/
│   ├── Dockerfile
│   ├── app.py              # /, /health, /error, /metrics
│   ├── requirements.txt
│   ├── requirements-dev.txt
│   └── test_app.py
├── docs/
│   ├── RUNBOOK.md
│   └── SLO.md
├── grafana/
│   ├── dashboards/observability.json
│   └── provisioning/
│       ├── dashboards/dashboards.yml
│       └── datasources/datasources.yml
├── loki/loki-config.yml
├── prometheus/
│   ├── alert_rules.yml
│   └── prometheus.yml
├── promtail/promtail-config.yml
├── screenshots/
├── .env.example
├── deploy.sh
├── docker-compose.yml
├── health_check.sh
├── inventory.ini
├── rollback.sh
├── setup.sh
├── setup.yml
└── README.md
```

`logs/` and `app/__pycache__/` are runtime output and git-ignored.

## Branching Strategy

- **`main`** — stable.
- **`dev`** — active development; work lands here first.

CI and security pipelines run on both branches; pull requests target `main`.
