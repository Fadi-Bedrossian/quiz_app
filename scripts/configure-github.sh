#!/usr/bin/env bash
set -euo pipefail
: "${GITHUB_OWNER:=Fadi-Bedrossian}"
: "${GITHUB_REPO:=quiz_app}"
REPO="${GITHUB_OWNER}/${GITHUB_REPO}"
command -v gh >/dev/null || { echo "GitHub CLI (gh) is required"; exit 1; }
gh auth status >/dev/null

set_env_vars() {
  local ENV=$1 ROOT="infra/environments/$1"
  gh variable set AZURE_DEPLOY_CLIENT_ID --env "$ENV" --repo "$REPO" --body "$(terraform -chdir="$ROOT" output -raw deploy_client_id)"
  gh variable set PUBLIC_URL --env "$ENV" --repo "$REPO" --body "$(terraform -chdir="$ROOT" output -raw public_url)"
  gh variable set PUBLIC_IP_NAME --env "$ENV" --repo "$REPO" --body "$(terraform -chdir="$ROOT" output -raw public_ip_name)"
  gh variable set KEY_VAULT_NAME --env "$ENV" --repo "$REPO" --body "$(terraform -chdir="$ROOT" output -raw key_vault_name)"
  gh variable set WORKLOAD_IDENTITY_CLIENT_ID --env "$ENV" --repo "$REPO" --body "$(terraform -chdir="$ROOT" output -raw workload_identity_client_id)"
  gh variable set POSTGRES_HOST --env "$ENV" --repo "$REPO" --body "$(terraform -chdir="$ROOT" output -raw postgres_host)"
  gh variable set POSTGRES_DATABASE --env "$ENV" --repo "$REPO" --body "$(terraform -chdir="$ROOT" output -raw postgres_database)"
  gh variable set POSTGRES_ADMIN_USER --env "$ENV" --repo "$REPO" --body "$(terraform -chdir="$ROOT" output -raw postgres_admin_user)"
  gh variable set ACR_NAME --env "$ENV" --repo "$REPO" --body "$(terraform -chdir="$ROOT" output -raw acr_name)"
}
set_env_vars dev
set_env_vars prod
echo "Configured dev/prod GitHub Environment variables from Terraform outputs."
