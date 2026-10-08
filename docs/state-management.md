# Terraform state management

The repository uses three independent remote Terraform state blobs in one Azure Storage container.

| Root | State key | Owns |
|---|---|---|
| `infra/shared` | `shared.tfstate` | VNet/subnet, AKS, ACR, Key Vault, Log Analytics, Application Insights, shared secrets/integration |
| `infra/environments/dev` | `dev.tfstate` | Dev identities/RBAC, Workload Identity federation, dev Public IP/DNS |
| `infra/environments/prod` | `prod.tfstate` | Prod identities/RBAC, Workload Identity federation, prod Public IP/DNS |

The environment roots consume outputs from `shared.tfstate` through `terraform_remote_state`; they do not own or rewrite shared AKS/ACR/Key Vault resources.

The Kubernetes observability stack is **not** a fourth Terraform state. Prometheus, Grafana, Loki, Fluent Bit and Sloth are deployed by `.github/workflows/observability.yml` into the existing AKS cluster.

Grafana also does not own a separate Terraform Public IP. It reuses the prod Public IP/Traefik endpoint at `/grafana`.

## Locking

The `azurerm` backend stores state in Azure Blob Storage. Terraform uses a blob lease for state locking.

All Terraform plan/apply/destroy commands use `-lock-timeout=5m`, so a second process waits for a legitimate lock instead of immediately failing.

The Infrastructure workflow also uses the `terraform-infrastructure` GitHub Actions concurrency group for manual state-changing operations.

Do not use `-lock=false` in CI. Do not force-unlock until you have verified there is no live Terraform process holding the lease.

## Backend authentication

The backend is bootstrapped by `scripts/bootstrap-azure.sh`.

Ongoing access uses Microsoft Entra ID and GitHub OIDC:

```text
use_oidc=true
use_azuread_auth=true
```

No storage-account key or long-lived Azure client secret is required for normal GitHub Actions execution.

This Microsoft Entra/OIDC usage is infrastructure authentication. The quiz application itself currently has no end-user authentication layer.

## Dependency order

```text
bootstrap backend
    ↓
shared resources
    ↓
dev/prod environment resources
    ↓
application deployments
    ↓
shared Kubernetes observability deployment
```

The Infrastructure workflow ensures the shared root is initialized/validated before applying the selected environment.

## Destruction order

For a complete teardown:

1. Remove Kubernetes ingress/Helm workloads that are using Terraform-managed Public IPs.
2. Destroy `prod.tfstate`.
3. Destroy `dev.tfstate`.
4. Destroy `shared.tfstate`.
5. Delete the bootstrap state/resource groups only after all Terraform states are gone.

The observability namespace can be removed before shared AKS destruction, but it has no separate Public IP or Terraform state.

See [`wiki/Rebuild-Guide.md`](../wiki/Rebuild-Guide.md) for exact commands.
