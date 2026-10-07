#!/usr/bin/env bash
set -euo pipefail
: "${AZURE_SUBSCRIPTION_ID:?set AZURE_SUBSCRIPTION_ID}"
: "${AZURE_TENANT_ID:?set AZURE_TENANT_ID}"
: "${GITHUB_OWNER:=Fadi-Bedrossian}"
: "${GITHUB_REPO:=quiz_app}"
LOCATION="${AZURE_LOCATION:-westeurope}"
STATE_RG="${TFSTATE_RESOURCE_GROUP:-sg-tfstate-rg}"
PROJECT_RG="${AZURE_RESOURCE_GROUP:-sg-quiz-rg}"
CONTAINER="${TFSTATE_CONTAINER:-tfstate}"
SUFFIX=$(printf '%s' "$AZURE_SUBSCRIPTION_ID" | sha256sum | cut -c1-8)
STATE_ACCOUNT="${TFSTATE_STORAGE_ACCOUNT:-sgquiztf${SUFFIX}}"
IDENTITY="sg-gha-terraform"

az account set --subscription "$AZURE_SUBSCRIPTION_ID"
for PROVIDER in Microsoft.ContainerService Microsoft.Network Microsoft.ContainerRegistry Microsoft.KeyVault Microsoft.DBforPostgreSQL Microsoft.OperationalInsights Microsoft.Insights Microsoft.Cdn Microsoft.ManagedIdentity; do
  az provider register --namespace "$PROVIDER" --wait >/dev/null
done
az group create -n "$STATE_RG" -l "$LOCATION" -o none
az group create -n "$PROJECT_RG" -l "$LOCATION" -o none
az storage account create -g "$STATE_RG" -n "$STATE_ACCOUNT" -l "$LOCATION" --sku Standard_LRS --kind StorageV2 --min-tls-version TLS1_2 --allow-blob-public-access false -o none
ACCOUNT_KEY=$(az storage account keys list -g "$STATE_RG" -n "$STATE_ACCOUNT" --query '[0].value' -o tsv)
az storage container create --account-name "$STATE_ACCOUNT" --name "$CONTAINER" --account-key "$ACCOUNT_KEY" -o none
az storage blob service-properties update --account-name "$STATE_ACCOUNT" --account-key "$ACCOUNT_KEY" --enable-versioning true --enable-delete-retention true --delete-retention-days 7 -o none
unset ACCOUNT_KEY

az identity create -g "$PROJECT_RG" -n "$IDENTITY" -l "$LOCATION" -o none
CLIENT_ID=$(az identity show -g "$PROJECT_RG" -n "$IDENTITY" --query clientId -o tsv)
PRINCIPAL_ID=$(az identity show -g "$PROJECT_RG" -n "$IDENTITY" --query principalId -o tsv)
IDENTITY_ID=$(az identity show -g "$PROJECT_RG" -n "$IDENTITY" --query id -o tsv)
PROJECT_RG_ID=$(az group show -n "$PROJECT_RG" --query id -o tsv)
STATE_ID=$(az storage account show -g "$STATE_RG" -n "$STATE_ACCOUNT" --query id -o tsv)

for ROLE in "Contributor" "User Access Administrator"; do
  az role assignment create --assignee-object-id "$PRINCIPAL_ID" --assignee-principal-type ServicePrincipal --role "$ROLE" --scope "$PROJECT_RG_ID" -o none 2>/dev/null || true
done
az role assignment create --assignee-object-id "$PRINCIPAL_ID" --assignee-principal-type ServicePrincipal --role "Storage Blob Data Contributor" --scope "$STATE_ID" -o none 2>/dev/null || true
CURRENT_USER_ID=$(az ad signed-in-user show --query id -o tsv 2>/dev/null || true)
if [ -n "$CURRENT_USER_ID" ]; then
  az role assignment create --assignee-object-id "$CURRENT_USER_ID" --assignee-principal-type User --role "Storage Blob Data Contributor" --scope "$STATE_ID" -o none 2>/dev/null || true
fi
az storage account update -g "$STATE_RG" -n "$STATE_ACCOUNT" --allow-shared-key-access false -o none

create_fic() {
  local NAME=$1 SUBJECT=$2
  if ! az identity federated-credential show -g "$PROJECT_RG" --identity-name "$IDENTITY" -n "$NAME" >/dev/null 2>&1; then
    az identity federated-credential create -g "$PROJECT_RG" --identity-name "$IDENTITY" -n "$NAME" --issuer "https://token.actions.githubusercontent.com" --subject "$SUBJECT" --audiences "api://AzureADTokenExchange" -o none
  fi
}
create_fic pull-request "repo:${GITHUB_OWNER}/${GITHUB_REPO}:pull_request"
create_fic dev "repo:${GITHUB_OWNER}/${GITHUB_REPO}:environment:dev"
create_fic prod "repo:${GITHUB_OWNER}/${GITHUB_REPO}:environment:prod"

cat <<EOF
Bootstrap complete.
Set these GitHub repository variables:
AZURE_SUBSCRIPTION_ID=$AZURE_SUBSCRIPTION_ID
AZURE_TENANT_ID=$AZURE_TENANT_ID
AZURE_INFRA_CLIENT_ID=$CLIENT_ID
TFSTATE_RESOURCE_GROUP=$STATE_RG
TFSTATE_STORAGE_ACCOUNT=$STATE_ACCOUNT
TFSTATE_CONTAINER=$CONTAINER
AZURE_RESOURCE_GROUP=$PROJECT_RG
AKS_NAME=sg-quiz-aks
EOF
