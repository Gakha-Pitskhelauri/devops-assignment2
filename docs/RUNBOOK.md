# Incident Response Runbook

Playbooks for responding to alerts fired by this project.

## General incident flow

1. **Acknowledge** the alert in Grafana Alerting UI
2. **Assess** the impact via `docker compose ps` and dashboards
3. **Diagnose** using logs (Grafana Explore → Loki) and metrics (Prometheus)
4. **Mitigate** using one of the specific playbooks below
5. **Document** the incident afterward (what fired, what fixed it, follow-ups)

---

## Alert: HighErrorRate

**Meaning:** The application produced more than 5 errors in the last minute
(`increase(app_errors_total[1m]) > 5`).

**Symptoms:**
- The alert appears in Grafana → Alerting → Alert rules with state "Firing"
- Errors visible in Loki: `{job="flask-app"} | json | level="ERROR"`

**Diagnostic steps:**

1. Check the app is running:
```bash
   docker compose ps
```

2. Inspect the last error logs from the app:
```bash
   docker compose logs app --tail=100
```

3. Query recent error rate in Prometheus (http://localhost:9090):

rate(app_errors_total[5m])


**Mitigation options:**

- **Bug in deployed version** → roll back:
```bash
  ./rollback.sh
```

- **Transient issue** → restart the app container:
```bash
  docker compose restart app
```

- **Confirmed dependency failure** → check external services, restore, then verify

---

## Alert: ServiceDown

**Meaning:** Prometheus has been unable to scrape the `flask-app` target for over 1 minute.

**Symptoms:**
- Alert firing in Grafana / Prometheus
- Grafana dashboard panels show "No data"

**Diagnostic steps:**

1. Check if the app container is running:
```bash
   docker compose ps app
```

2. Check container logs for crashes:
```bash
   docker compose logs app --tail=50
```

3. Verify the app is reachable from Prometheus's network:
```bash
   docker compose exec prometheus wget -qO- http://app:5000/health
```

**Mitigation options:**

- **App container is not running** → bring it up:
```bash
  docker compose up -d app
```

- **App is running but unhealthy** → try a restart:
```bash
  docker compose restart app
```

- **Restart fails or the new deploy is broken** → roll back:
```bash
  ./rollback.sh
```

---

## General recovery commands

| Task                          | Command                                    |
|-------------------------------|--------------------------------------------|
| Bring up full stack           | `./deploy.sh` or `docker compose up -d`    |
| Roll back to previous version | `./rollback.sh`                            |
| Restart a single service      | `docker compose restart <service>`         |
| View logs for a service       | `docker compose logs <service> --tail=100` |
| Live health monitoring        | `./health_check.sh`                        |
| Tear down everything          | `docker compose down`                      |

## Escalation

If none of the above resolves the issue:

1. Capture logs from all services: `docker compose logs > incident.log`
2. Capture current metrics snapshot from Prometheus
3. File an issue in the repository with the collected data


