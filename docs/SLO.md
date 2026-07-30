# Service Level Objectives (SLO)

This document defines the reliability targets for the Observability Lab application and how we measure them.

## Overview

- **Service**: Observability Lab Flask application
- **Owner**: DevOps Team
- **Review cadence**: Monthly

## Service Level Indicators (SLIs)

An SLI is a measurement of a specific aspect of the service. We track two SLIs, computed from Prometheus metrics:

### 1. Availability

The percentage of successful HTTP requests over a rolling window.

**Formula:**

availability = (successful_requests / total_requests) * 100


**PromQL:**

(sum(rate(app_requests_total[5m])) - sum(rate(app_errors_total[5m])))
/ sum(rate(app_requests_total[5m])) * 100


### 2. Service Health

Whether the application is up and being scraped successfully by Prometheus.

**PromQL:**

up{job="flask-app"}


## Service Level Objectives (SLOs)

| SLI          | Target                        | Window     |
|--------------|-------------------------------|------------|
| Availability | 99.5% of requests succeed     | 30 days    |
| Health       | Prometheus target UP          | Continuous |

## Error Budget

**Error budget = 1 - SLO = 0.5% over 30 days.**

This translates to approximately **3.6 hours** of unavailability allowed per month
before we breach the SLO.

Usage policy:
- If budget remaining > 50%: normal feature delivery
- If budget remaining 10-50%: prioritize reliability work
- If budget < 10%: freeze feature deploys, focus exclusively on reliability

## Alerting

The following alert rules are triggered when we are at risk of breaching an SLO:

| Alert          | Threshold                    | Severity |
|----------------|------------------------------|----------|
| HighErrorRate  | > 5 errors in 1 minute       | Critical |
| ServiceDown    | scrape failure > 1 minute    | Critical |

See `docs/RUNBOOK.md` for the response procedure.

## SLA

There is no external customer-facing SLA for this project. The above SLOs are
internal targets used to drive engineering priorities.
