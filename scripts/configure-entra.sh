#!/usr/bin/env bash
set -euo pipefail
: "${AZURE_TENANT_ID:?set AZURE_TENANT_ID}"
: "${DEV_URL:?set DEV_URL from Terraform dev output}"
: "${PROD_URL:?set PROD_URL from Terraform prod output}"
APP_NAME="${ENTRA_APP_NAME:-sg-quiz-app}"
az login --tenant "$AZURE_TENANT_ID" >/dev/null
APP_ID=$(az ad app list --display-name "$APP_NAME" --query '[0].appId' -o tsv)
if [ -z "$APP_ID" ]; then
  APP_ID=$(az ad app create --display-name "$APP_NAME" --sign-in-audience AzureADMyOrg --query appId -o tsv)
fi
OBJ_ID=$(az ad app show --id "$APP_ID" --query id -o tsv)
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
az rest --method PATCH --uri "https://graph.microsoft.com/v1.0/applications/$OBJ_ID" --headers 'Content-Type=application/json' --body "$MANIFEST" >/dev/null
cat <<EOF
Entra app configured.
ENTRA_CLIENT_ID=$APP_ID
ENTRA_AUDIENCE=api://$APP_ID
Redirect URIs:
- $DEV_URL
- $PROD_URL
EOF
