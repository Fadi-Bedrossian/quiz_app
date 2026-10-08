# Deployment runbook

1. Run `scripts/bootstrap-azure.sh` once.
2. Configure the GitHub repository variables printed by the script.
3. Apply `infra/shared`.
4. Apply `infra/environments/dev` and `infra/environments/prod`.
5. Push to `develop` for dev deployment.
6. Run the Application workflow manually with `prod` for production after the GitHub `prod` Environment approval.

The quiz and admin UI/API are intentionally public. HTTPS is provided by Traefik, cert-manager and Let's Encrypt. No Microsoft Entra application authentication is required.

For rollback, redeploy a previous commit SHA as the Helm image tag. Infrastructure rollback should be performed with a reviewed Terraform change rather than restoring state files manually.
