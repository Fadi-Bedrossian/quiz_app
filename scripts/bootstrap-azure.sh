#!/usr/bin/env bash
set -euo pipefail

: "${AZURE_SUBSCRIPTION_ID:?set AZURE_SUBSCRIPTION_ID}"
: "${AZURE_TENANT_ID:?set AZURE_TENANT_ID}"
: "${GITHUB_OWNER:=Fadi-Bedrossian}"
: "${GITHUB_REPO:=quiz_app}"
: "${GITHUB_OWNER_ID:=59285089}"
: "${GITHUB_REPO_ID:=1408354219}"

LOCATION="${AZURE_LOCATION:-northeurope}"
STATE_RG="${TFSTATE_RESOURCE_GROUP:-sg-tfstate-rg}"
PROJECT_RG="${AZURE_RESOURCE_GROUP:-sg-quiz-rg}"
CONTAINER="${TFSTATE_CONTAINER:-tfstate}"
SUFFIX=$(printf '%s' "$AZURE_SUBSCRIPTION_ID" | sha256sum | cut -c1-8)
STATE_ACCOUNT="${TFSTATE_STORAGE_ACCOUNT:-sgquiztf${SUFFIX}}"
IDENTITY="sg-gha-terraform"

step() {
  printf '\n==> %s\n' "$1"
}

ensure_rg() {
  local name=$1
  if [ "$(az group exists --name "$name")" = "true" ]; then
    local current_location
    current_location=$(az group show --name "$name" --query location -o tsv)
    echo "Resource group $name already exists (metadata location: $current_location); reusing it."
  else
    echo "Creating resource group $name in $LOCATION..."
    az group create -n "$name" -l "$LOCATION" -o none
  fi
}

step "Selecting Azure subscription"
az account set --subscription "$AZURE_SUBSCRIPTION_ID"
echo "Subscription: $AZURE_SUBSCRIPTION_ID"
echo "Tenant:       $AZURE_TENANT_ID"
echo "Region:       $LOCATION"

step "Registering required Azure resource providers"
for PROVIDER in \
  Microsoft.ContainerService \
  Microsoft.Network \
  Microsoft.ContainerRegistry \
  Microsoft.KeyVault \
  Microsoft.DBforPostgreSQL \
  Microsoft.OperationalInsights \
  Microsoft.Insights \
  Microsoft.Cdn \
  Microsoft.ManagedIdentity
do
  STATE=$(az provider show --namespace "$PROVIDER" --query registrationState -o tsv 2>/dev/null || true)
  if [ "$STATE" = "Registered" ]; then
    echo "✓ $PROVIDER already registered"
  else
    echo "Registering $PROVIDER..."
    az provider register --namespace "$PROVIDER" --wait >/dev/null
    echo "✓ $PROVIDER registered"
  fi
done

step "Creating or reusing resource groups"
ensure_rg "$STATE_RG"
ensure_rg "$PROJECT_RG"

step "Creating or reusing Terraform state storage account"
if az storage account show -g "$STATE_RG" -n "$STATE_ACCOUNT" >/dev/null 2>&1; then
  STORAGE_LOCATION=$(az storage account show -g "$STATE_RG" -n "$STATE_ACCOUNT" --query primaryLocation -o tsv)
  echo "✓ Storage account $STATE_ACCOUNT already exists in $STORAGE_LOCATION"
else
  echo "Creating storage account $STATE_ACCOUNT in $LOCATION..."
  az storage account create \
    -g "$STATE_RG" \
    -n "$STATE_ACCOUNT" \
    -l "$LOCATION" \
    --sku Standard_LRS \
    --kind StorageV2 \
    --min-tls-version TLS1_2 \
    --allow-blob-public-access false \
    -o none
  echo "✓ Storage account created"
fi

step "Configuring Terraform state container"
SHARED_KEY_ACCESS=$(az storage account show -g "$STATE_RG" -n "$STATE_ACCOUNT" --query allowSharedKeyAccess -o tsv)

if [ "$SHARED_KEY_ACCESS" = "false" ]; then
  az storage container create \
    --account-name "$STATE_ACCOUNT" \
    --name "$CONTAINER" \
    --auth-mode login \
    -o none
else
  ACCOUNT_KEY=$(az storage account keys list -g "$STATE_RG" -n "$STATE_ACCOUNT" --query '[0].value' -o tsv)
  az storage container create \
    --account-name "$STATE_ACCOUNT" \
    --name "$CONTAINER" \
    --account-key "$ACCOUNT_KEY" \
    -o none
  unset ACCOUNT_KEY
fi

az storage account blob-service-properties update \
  --resource-group "$STATE_RG" \
  --account-name "$STATE_ACCOUNT" \
  --enable-versioning true \
  --enable-delete-retention true \
  --delete-retention-days 7 \
  -o none
echo "✓ State container $CONTAINER configured with versioning and soft delete"

step "Creating or reusing GitHub Actions managed identity"
if az identity show -g "$PROJECT_RG" -n "$IDENTITY" >/dev/null 2>&1; then
  echo "✓ Managed identity $IDENTITY already exists"
else
  az identity create -g "$PROJECT_RG" -n "$IDENTITY" -l "$LOCATION" -o none
  echo "✓ Managed identity $IDENTITY created"
fi

CLIENT_ID=$(az identity show -g "$PROJECT_RG" -n "$IDENTITY" --query clientId -o tsv)
PRINCIPAL_ID=$(az identity show -g "$PROJECT_RG" -n "$IDENTITY" --query principalId -o tsv)
PROJECT_RG_ID=$(az group show -n "$PROJECT_RG" --query id -o tsv)
STATE_ID=$(az storage account show -g "$STATE_RG" -n "$STATE_ACCOUNT" --query id -o tsv)

step "Assigning Azure RBAC"
for ROLE in "Contributor" "User Access Administrator"; do
  echo "Ensuring $ROLE on $PROJECT_RG..."
  az role assignment create \
    --assignee-object-id "$PRINCIPAL_ID" \
    --assignee-principal-type ServicePrincipal \
    --role "$ROLE" \
    --scope "$PROJECT_RG_ID" \
    -o none 2>/dev/null || true
done

echo "Ensuring Storage Blob Data Contributor on Terraform state storage..."
az role assignment create \
  --assignee-object-id "$PRINCIPAL_ID" \
  --assignee-principal-type ServicePrincipal \
  --role "Storage Blob Data Contributor" \
  --scope "$STATE_ID" \
  -o none 2>/dev/null || true

CURRENT_USER_ID=$(az ad signed-in-user show --query id -o tsv 2>/dev/null || true)
if [ -n "$CURRENT_USER_ID" ]; then
  echo "Ensuring your signed-in user can access Terraform state..."
  az role assignment create \
    --assignee-object-id "$CURRENT_USER_ID" \
    --assignee-principal-type User \
    --role "Storage Blob Data Contributor" \
    --scope "$STATE_ID" \
    -o none 2>/dev/null || true
fi

az storage account update \
  -g "$STATE_RG" \
  -n "$STATE_ACCOUNT" \
  --allow-shared-key-access false \
  -o none

step "Creating GitHub OIDC federated credentials"
create_fic() {
  local NAME=$1
  local SUBJECT=$2
  local EXISTING_SUBJECT

  EXISTING_SUBJECT=$(az identity federated-credential show \
    -g "$PROJECT_RG" \
    --identity-name "$IDENTITY" \
    -n "$NAME" \
    --query subject \
    -o tsv 2>/dev/null || true)

  if [ -z "$EXISTING_SUBJECT" ]; then
    az identity federated-credential create \
      -g "$PROJECT_RG" \
      --identity-name "$IDENTITY" \
      -n "$NAME" \
      --issuer "https://token.actions.githubusercontent.com" \
      --subject "$SUBJECT" \
      --audiences "api://AzureADTokenExchange" \
      -o none
    echo "✓ $NAME created"
  elif [ "$EXISTING_SUBJECT" = "$SUBJECT" ]; then
    echo "✓ $NAME already matches GitHub immutable OIDC subject"
  else
    az identity federated-credential update \
      -g "$PROJECT_RG" \
      --identity-name "$IDENTITY" \
      -n "$NAME" \
      --issuer "https://token.actions.githubusercontent.com" \
      --subject "$SUBJECT" \
      --audiences "api://AzureADTokenExchange" \
      -o none
    echo "✓ $NAME updated to GitHub immutable OIDC subject"
  fi
}

IMMUTABLE_REPO="repo:${GITHUB_OWNER}@${GITHUB_OWNER_ID}/${GITHUB_REPO}@${GITHUB_REPO_ID}"
create_fic pull-request "${IMMUTABLE_REPO}:pull_request"
create_fic dev "${IMMUTABLE_REPO}:environment:dev"
create_fic prod "${IMMUTABLE_REPO}:environment:prod"

step "Bootstrap complete"
cat <<EOF
Set these GitHub repository variables:
AZURE_SUBSCRIPTION_ID=$AZURE_SUBSCRIPTION_ID
AZURE_TENANT_ID=$AZURE_TENANT_ID
AZURE_INFRA_CLIENT_ID=$CLIENT_ID
TFSTATE_RESOURCE_GROUP=$STATE_RG
TFSTATE_STORAGE_ACCOUNT=$STATE_ACCOUNT
TFSTATE_CONTAINER=$CONTAINER
AZURE_RESOURCE_GROUP=$PROJECT_RG
AKS_NAME=sg-quiz-aks
AZURE_LOCATION=$LOCATION
GITHUB_OWNER_ID=$GITHUB_OWNER_ID
GITHUB_REPO_ID=$GITHUB_REPO_ID
EOF
