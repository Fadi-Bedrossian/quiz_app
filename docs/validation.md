# Repository validation

This document describes the validation surfaces currently built into the repository.

## Application validation

The Application workflow checks:

- repository consistency with `scripts/repo-check.py`
- Python linting with Ruff
- FastAPI tests
- frontend lint/tests/build
- Helm lint
- Trivy filesystem/image scanning
- HTTPS smoke test against `/api/healthz`

The API test suite includes a public-admin CRUD test, matching the current application access model: quiz and Admin API operations do not require an application-user bearer token.

## Infrastructure validation

The Infrastructure workflow checks:

- Terraform formatting
- Terraform validation
- Trivy configuration scanning
- remote-state initialization
- plan/apply using Azure OIDC
- state locking with `-lock-timeout=5m`

The architecture uses three Terraform state roots: shared, dev, and prod.

Regional Azure quota/SKU availability must still be considered during real deployment. In particular, the current design intentionally reuses the prod Public IP for Grafana instead of allocating a separate monitoring Public IP.

## Observability validation

The Observability workflow validates:

- YAML files under `observability/`
- Grafana dashboard JSON
- rendering of pinned `kube-prometheus-stack` Helm templates
- rendering of pinned Sloth Helm templates

At deployment time it also checks/creates:

- `observability` namespace
- Prometheus/Grafana/Alertmanager
- Loki
- Fluent Bit
- Sloth
- ServiceMonitors for dev and prod
- generated Prometheus SLO rules
- Grafana dashboard ConfigMap
- Grafana HTTPS ingress through `traefik-prod`

Expected SLO resources:

```text
quiz-api-dev
quiz-api-prod
```

Each environment defines three objectives/guardrails.

## Runtime validation

Because the AKS API server is restricted, use AKS Run Command for reliable checks:

```bash
az aks command invoke   -g sg-quiz-rg   -n sg-quiz-aks   --command "
    kubectl get pods -n quiz-dev;
    kubectl get pods -n quiz-prod;
    kubectl get pods -n observability;
    kubectl get servicemonitors -n observability;
    kubectl get prometheusservicelevels -n observability
  "
```

Application health:

```bash
curl -fsS https://<dev-hostname>/api/healthz
curl -fsS https://<prod-hostname>/api/healthz
```

Grafana:

```text
https://<prod-hostname>/grafana
```

Dashboard:

```text
https://<prod-hostname>/grafana/d/quiz-observability
```

## Security validation boundaries

The current model intentionally separates infrastructure identity from application access:

- GitHub Actions -> Azure uses OIDC.
- Pods -> Key Vault use AKS Workload Identity.
- Grafana requires its own admin credentials.
- Quiz/Admin application endpoints are public over HTTPS.
- Prometheus, Loki, Alertmanager, and Sloth remain internal-only.

See the [Architecture wiki](../wiki/Architecture.md) for the complete topology.
