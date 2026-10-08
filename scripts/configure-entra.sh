#!/usr/bin/env bash
set -euo pipefail
: "${AZURE_TENANT_ID:?set AZURE_TENANT_ID}"
: "${DEV_URL:?set DEV_URL from Terraform dev output}"
: "${PROD_URL:?set PROD_URL from Terraform prod output}"
APP_NAME="${ENTRA_APP_NAME:-sg-quiz-app}"

for URL in "$DEV_URL" "$PROD_URL"; do
  if [[ "$URL" != https://* ]]; then
    echo "Entra SPA redirect URI must use HTTPS: $URL" >&2
    exit 1
  fi
done

CURRENT_TENANT="$(az account show --query tenantId -o tsv 2>/dev/null || true)"

if [[ "$CURRENT_TENANT" == "$AZURE_TENANT_ID" ]]; then
  echo "Using existing Azure CLI session for tenant $AZURE_TENANT_ID."
else
  if [[ -n "$CURRENT_TENANT" ]]; then
    echo "Current Azure CLI tenant is $CURRENT_TENANT; authentication is required for $AZURE_TENANT_ID."
  else
    echo "No active Azure CLI session found for tenant $AZURE_TENANT_ID."
  fi

  echo "Starting Azure CLI device-code login..."
  az login --tenant "$AZURE_TENANT_ID" --use-device-code >/dev/null
fi

APP_ID="${ENTRA_CLIENT_ID:-}"

if [[ -n "$APP_ID" ]]; then
  echo "Using existing Entra application $APP_ID."
else
  APP_ID="$(az ad app list \
    --show-mine \
    --display-name "$APP_NAME" \
    --query '[0].appId' \
    -o tsv 2>/dev/null || true)"

  if [[ -n "$APP_ID" ]]; then
    echo "Using existing owned Entra application $APP_ID."
  else
    echo "No owned Entra application named '$APP_NAME' was found; creating one."

    CREATE_ERROR="$(mktemp)"
    if ! APP_ID="$(az ad app create \
      --display-name "$APP_NAME" \
      --sign-in-audience AzureADMyOrg \
      --query appId \
      -o tsv 2>"$CREATE_ERROR")"; then
      cat "$CREATE_ERROR" >&2
      rm -f "$CREATE_ERROR"

      cat >&2 <<'EOF'
Unable to create the Entra application registration.

Azure subscription Owner/Contributor permissions do not grant Microsoft Entra
directory permissions. Ask a tenant administrator to either:
  - allow users to register applications, or
  - assign you the Microsoft Entra "Application Developer" role
    (or Cloud Application Administrator / Application Administrator).

If an administrator creates the app for you, set ENTRA_CLIENT_ID to its
Application (client) ID and rerun this script.
EOF
      exit 1
    fi
    rm -f "$CREATE_ERROR"
  fi
fi

SHOW_ERROR="$(mktemp)"
if ! OBJ_ID="$(az ad app show --id "$APP_ID" --query id -o tsv 2>"$SHOW_ERROR")"; then
  cat "$SHOW_ERROR" >&2
  rm -f "$SHOW_ERROR"
  echo "Cannot read Entra application $APP_ID. Ensure you own it or have an application administrator role." >&2
  exit 1
fi
rm -f "$SHOW_ERROR"
SCOPE_ID=$(az rest --method GET --uri "https://graph.microsoft.com/v1.0/applications/$OBJ_ID" --query "api.oauth2PermissionScopes[?value=='Quiz.Access'].id | [0]" -o tsv 2>/dev/null || true)
if [ -z "$SCOPE_ID" ]; then
  SCOPE_ID=$(python - <<'PY2'
import uuid
print(uuid.uuid4())
PY2
)
fi
MANIFEST=$(cat <<EOF
{"identifierUris":["api://$APP_ID"],"groupMembershipClaims":"SecurityGroup","api":{"requestedAccessTokenVersion":2,"oauth2PermissionScopes":[{"adminConsentDescription":"Access the Quiz API","adminConsentDisplayName":"Access Quiz API","id":"$SCOPE_ID","isEnabled":true,"type":"User","userConsentDescription":"Access the Quiz API","userConsentDisplayName":"Access Quiz API","value":"Quiz.Access"}]},"spa":{"redirectUris":["$DEV_URL","$PROD_URL"]}}
EOF
)
PATCH_ERROR="$(mktemp)"
if ! az rest \
  --method PATCH \
  --uri "https://graph.microsoft.com/v1.0/applications/$OBJ_ID" \
  --headers 'Content-Type=application/json' \
  --body "$MANIFEST" \
  >/dev/null 2>"$PATCH_ERROR"; then
  cat "$PATCH_ERROR" >&2
  rm -f "$PATCH_ERROR"

  cat >&2 <<EOF
Unable to update Entra application $APP_ID.
Ensure the signed-in user owns this application or has an appropriate
Microsoft Entra application administrator role.
EOF
  exit 1
fi
rm -f "$PATCH_ERROR"
cat <<EOF
Entra app configured.
ENTRA_CLIENT_ID=$APP_ID
ENTRA_AUDIENCE=api://$APP_ID
Redirect URIs:
- $DEV_URL
- $PROD_URL
EOF
