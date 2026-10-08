# Quiz application observability

This directory deploys one shared AKS observability stack for both `quiz-dev` and `quiz-prod`.

## Stack

- Prometheus Operator + Prometheus + Grafana from `kube-prometheus-stack`.
- Sloth Kubernetes controller for SLI/SLO recording rules and multi-window multi-burn alerts.
- Loki single-binary deployment with a 10 Gi Azure Disk and 7-day retention.
- Fluent Bit as a DaemonSet scraping Kubernetes container logs from every node and sending them to Loki.
- One provisioned Grafana dashboard: **Quiz App - Application, Golden Signals, SLOs & Logs**.

Grafana is exposed at `/grafana` on the existing production HTTPS hostname through `traefik-prod`. Prometheus, Loki, Alertmanager, and the remaining monitoring services stay internal-only (`ClusterIP`).

## Service levels

| Level | Indicator | Target | 30-day error budget |
| --- | --- | ---: | ---: |
| SLO | HTTP availability (non-health requests that are not 5xx) | 99.9% | 0.1% failed requests |
| SLO | Request latency (non-health requests completed within 500 ms) | 95% | 5% slow requests |
| SLA guardrail | HTTP availability | 99.5% | 0.5% failed requests |

The 99.9% availability budget is approximately 43m12s of a 30-day window only as a time-equivalent intuition. The implemented SLI is request/event based, so the actual budget is 0.1% of requests.

The 99.5% SLA entry is an operational guardrail in Sloth, not a legal or contractual SLA by itself.

## Golden signals

- **Latency:** p50, p95, p99 from `quiz_http_request_duration_seconds`.
- **Traffic:** requests/sec and traffic by route from `quiz_http_requests_total`.
- **Errors:** 5xx ratio and Sloth availability burn rate.
- **Saturation:** application CPU and memory usage compared with Kubernetes resource limits.

Additional application metrics include in-flight requests, quiz submissions, and score distribution. Kubernetes metrics come from kube-state-metrics and node-exporter.

## Deployment order

1. Deploy the application change to **dev** and **prod** so `/metrics` exists and the API Service has the `app=quiz-api` label.
2. Run **Actions -> Observability -> Run workflow**. The workflow uses the existing `prod` GitHub Environment for OIDC credentials/approval and updates `traefik-prod` to also watch the `observability` namespace.
3. Wait for cert-manager to issue the Grafana TLS certificate, then open the HTTPS Grafana URL printed by the workflow.
4. Switch the dashboard Environment variable between `dev` and `prod` to validate both applications.

## Access Grafana

Grafana reuses the existing production public endpoint:

```text
https://<prod-hostname>/grafana
```

The username is:

```text
admin
```

The password is generated once and stored only in the Kubernetes Secret `observability/grafana-admin`. Retrieve it without exposing Prometheus/Loki/Alertmanager:

```bash
az aks command invoke \
  --resource-group sg-quiz-rg \
  --name sg-quiz-aks \
  --command "kubectl -n observability get secret grafana-admin -o jsonpath='{.data.admin-password}' | base64 -d; echo"
```

Prometheus, Loki, and Alertmanager remain internal services and are consumed through Grafana datasources/dashboards.

### Find the provisioned dashboard

After login, go to **Dashboards -> Browse** and open:

**Quiz App - Application, Golden Signals, SLOs & Logs**

Direct path:

```text
https://<prod-hostname>/grafana/d/quiz-observability
```

Use the **Environment** variable at the top of the dashboard to switch between `dev` and `prod`.

If the Grafana home page says `Recent dashboards: 0`, that only means no dashboard has been opened recently. It does not indicate a Prometheus scraping failure.

### Data sources

Under **Connections -> Data sources**, the expected provisioned data sources are:

```text
Prometheus
Loki
```

Prometheus provides application and Kubernetes metrics. Loki provides Kubernetes container logs collected by Fluent Bit.

### If the dashboard is missing

Verify the dashboard ConfigMap and Grafana sidecar:

```bash
az aks command invoke \
  -g sg-quiz-rg \
  -n sg-quiz-aks \
  --command "
    kubectl get configmap quiz-observability-dashboard -n observability --show-labels;
    POD=\$(kubectl get pods -n observability -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].metadata.name}');
    kubectl logs -n observability \$POD -c grafana-sc-dashboard --tail=100 || true
  "
```

The ConfigMap should have the `grafana_dashboard=1` label.

### If panels show no data

First verify that both ServiceMonitors exist:

```bash
az aks command invoke \
  -g sg-quiz-rg \
  -n sg-quiz-aks \
  --command "kubectl get servicemonitors -n observability"
```

Expected application monitors:

```text
quiz-api-dev
quiz-api-prod
```

The API metrics endpoint exports names such as:

```text
quiz_http_requests_total
quiz_http_request_duration_seconds
quiz_http_requests_in_progress
quiz_quiz_submissions_total
quiz_quiz_score_percent
```

Generate a few quiz requests in the selected environment, then refresh the dashboard. Rate-based panels need recent traffic in their time window.

## Useful checks

```bash
kubectl get pods -n observability
kubectl get servicemonitors -n observability
kubectl get prometheusservicelevels -n observability
kubectl get prometheusrules -n observability | grep quiz-api
kubectl logs -n observability deploy/loki --tail=100
kubectl logs -n observability ds/fluent-bit --tail=100
kubectl logs -n observability deploy/sloth --tail=100
```

Prometheus stores seven days of metrics on a 10 Gi Azure Disk. Loki stores seven days of logs on a separate 10 Gi Azure Disk. This is sized for the current lab/demo AKS cluster; increase retention and move Loki to object storage before treating it as a high-volume production logging platform.
