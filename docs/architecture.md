# Architecture decisions

## One AKS cluster

A single cluster is used because cost was prioritized over hard cluster-level isolation. Environment separation is implemented with namespaces, separate Helm releases, identities, databases, Front Door endpoints and Terraform states.

## Front Door instead of a custom domain

Azure Front Door provides an Azure-generated HTTPS hostname without requiring the user to own a DNS name. Each environment gets its own endpoint under one shared Front Door Standard profile.

## State boundaries

The `shared` state owns resources with a shared lifecycle. Dev and prod states own only environment-scoped resources. This prevents a dev apply from mutating prod state while avoiding duplicated AKS/ACR/PostgreSQL infrastructure.

## Secrets

PostgreSQL admin password and App Insights connection string are stored in Key Vault. AKS Workload Identity authorizes the API pod to mount them via Secrets Store CSI Driver.
