# Terraform state management

The repository intentionally uses three independent remote Terraform state blobs in one Azure Storage container:

| Root | State key | Owns |
|---|---|---|
| `infra/shared` | `shared.tfstate` | AKS, VNet, ACR, Key Vault, PostgreSQL server, monitoring and Front Door profile |
| `infra/environments/dev` | `dev.tfstate` | Dev database, identities/RBAC, public IP and Front Door route |
| `infra/environments/prod` | `prod.tfstate` | Prod database, identities/RBAC, public IP and Front Door route |

The environment roots consume outputs from `shared.tfstate` through `terraform_remote_state`; they do not own or rewrite shared resources.

## Locking

The `azurerm` backend stores state in Azure Blob Storage, whose backend locking is based on a blob lease. Terraform acquires that lock before state-changing operations. All plan/apply/destroy commands in this repo add `-lock-timeout=5m`, so a second run waits for a legitimate lock rather than immediately failing.

GitHub Actions adds another layer with concurrency groups:

- `terraform-dev` serializes dev writes.
- `terraform-shared-prod` serializes shared/prod writes because prod depends on shared resources.
- PR plans can run concurrently across PRs, but the backend lease still protects each state blob.

Do not use `-lock=false` in CI. Do not force-unlock until you have verified there is no live Terraform process holding the lease.

## Authentication

The backend is bootstrapped once by `scripts/bootstrap-azure.sh`. Ongoing access uses Microsoft Entra ID and GitHub OIDC (`use_oidc=true`, `use_azuread_auth=true`) rather than a storage account key. Shared-key access is disabled after bootstrap.

## Destruction order

Destroy `prod.tfstate` and `dev.tfstate` before `shared.tfstate`. The manual workflow requires `confirm_destroy=true` and serializes destructive runs with the same concurrency groups as applies.
