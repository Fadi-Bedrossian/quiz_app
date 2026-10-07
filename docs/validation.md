# Validation performed for this generated repository

The generated repository was checked in the build sandbox with the tools available there.

Passed locally:

- dependency-free repository consistency checker (`scripts/repo-check.py`)
- Python bytecode compilation
- FastAPI test suite: 2 tests passed
- shell syntax for bootstrap/configuration scripts
- YAML parsing for GitHub Actions, Dependabot, Docker Compose and Helm values/Chart metadata
- JavaScript syntax for non-JSX source/config files
- NGINX template rendering and `nginx -t` syntax validation in an HTTP context
- static checks for separate `shared.tfstate`, `dev.tfstate`, `prod.tfstate`, `-lock-timeout=5m`, OIDC backend flags and absence of committed real-looking GUIDs
- provider-schema spot checks against AzureRM 4.61.0 documentation/source for the AKS and federated-identity fields used by the modules

Not executed in the sandbox because outbound dependency/tool downloads were unavailable:

- `terraform init`, `terraform fmt` and `terraform validate`
- `helm lint`
- frontend `npm install`, Vitest, ESLint and Vite build
- Docker image builds
- real Azure provisioning/deployment

Those checks are present in GitHub Actions and run in a normal networked GitHub runner before deployment. The first Azure deployment should still be reviewed with `terraform plan`, especially for regional SKU/quota availability and organization-specific Entra/RBAC policy.
