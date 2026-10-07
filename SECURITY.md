# Security

Do not commit Azure credentials, storage keys, database passwords, client secrets, kubeconfigs or `.tfstate` files.

GitHub Actions authenticates to Azure with workload identity federation (OIDC). Application pods use AKS Workload Identity to read Key Vault secrets. The PostgreSQL server uses private VNet integration. Public user traffic enters through Azure Front Door; the AKS frontend service restricts allowed Azure service tags and NGINX verifies the Front Door profile identifier on application requests.

If a secret is exposed, rotate it in Azure and invalidate any related credentials before removing it from Git history.
