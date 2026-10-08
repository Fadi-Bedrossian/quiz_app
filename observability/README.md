# Quiz application observability

This directory deploys one shared AKS observability stack for both `quiz-dev` and `quiz-prod`.

## Stack

- Prometheus Operator + Prometheus + Grafana from `kube-prometheus-stack`.
- Sloth Kubernetes controller for SLI/SLO recording rules and multi-window multi-burn alerts.
- Loki single-binary deployment with a 10 Gi Azure Disk and 7-day retention.
- Fluent Bit as a DaemonSet scraping Kubernetes container logs from every node and sending them to Loki.
- One provisioned Grafana dashboard: **Quiz App - Application, Golden Signals, SLOs & Logs**.

The deployment stays inside the existing AKS cluster and does not add a public monitoring endpoint.

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

1. Deploy the application change to **dev** so `/metrics` exists and the API Service has the `app=quiz-api` label.
2. Run **Actions -> Observability -> Run workflow**. The workflow uses the existing `prod` GitHub Environment for OIDC credentials/approval; it creates no new GitHub Environment.
3. Validate dev metrics, Sloth SLOs, Loki logs, and the Grafana dashboard.
4. Deploy the same application commit to **prod**.
5. Switch the dashboard Environment variable from `dev` to `prod` and verify production data.

## Access Grafana

From a terminal with AKS access:

```bash
az aks get-credentials --resource-group sg-quiz-rg --name sg-quiz-aks --overwrite-existing

kubectl -n observability get secret grafana-admin \
  -o jsonpath='{.data.admin-password}' | base64 -d; echo

kubectl -n observability port-forward svc/monitoring-grafana 3000:80
```

Then open `http://localhost:3000`, sign in as `admin`, and open **Quiz App - Application, Golden Signals, SLOs & Logs**.

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
