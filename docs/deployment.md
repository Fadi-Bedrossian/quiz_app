# Deployment runbook

1. Run `scripts/bootstrap-azure.sh` once.
2. Configure the GitHub repository variables printed by the script.
3. Apply `infra/shared`.
4. Apply `infra/environments/dev` and `infra/environments/prod`.
5. Run `scripts/configure-entra.sh` with the two Terraform public URLs.
6. Configure `ENTRA_CLIENT_ID`, `ENTRA_AUDIENCE`, and optional `ADMIN_GROUP_ID` in GitHub.
7. Push to `develop` for dev deployment.
8. Merge to `main` for production after the GitHub `prod` Environment approval.

For rollback, redeploy a previous commit SHA as the Helm image tag. Infrastructure rollback should be performed with a reviewed Terraform change rather than restoring state files manually.
