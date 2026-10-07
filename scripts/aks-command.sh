#!/usr/bin/env bash
set -euo pipefail

RESOURCE_GROUP="${1:?resource group is required}"
AKS_NAME="${2:?AKS name is required}"
COMMAND="${3:?command is required}"
FILE_PATH="${4:-}"

invoke_args=(
  aks command invoke
  --resource-group "$RESOURCE_GROUP"
  --name "$AKS_NAME"
  --command "$COMMAND"
  --no-wait
  -o json
)

if [[ -n "$FILE_PATH" ]]; then
  invoke_args+=(--file "$FILE_PATH")
fi

SUBMIT="$(az "${invoke_args[@]}")"
echo "$SUBMIT"

COMMAND_ID="$(jq -r '.id // .commandId // empty' <<<"$SUBMIT")"
if [[ -z "$COMMAND_ID" || "$COMMAND_ID" == "null" ]]; then
  echo "AKS command submission did not return a command id." >&2
  exit 1
fi

echo "AKS command id: $COMMAND_ID"

for attempt in $(seq 1 60); do
  set +e
  RESULT="$(az aks command result     --resource-group "$RESOURCE_GROUP"     --name "$AKS_NAME"     --command-id "$COMMAND_ID"     -o json 2>/tmp/aks-command-result.err)"
  rc=$?
  set -e

  if [[ $rc -ne 0 ]]; then
    if [[ $attempt -eq 60 ]]; then
      cat /tmp/aks-command-result.err >&2 || true
      echo "Timed out fetching AKS command result." >&2
      exit 1
    fi
    sleep 5
    continue
  fi

  STATE="$(jq -r '.provisioningState // empty' <<<"$RESULT")"
  EXIT_CODE="$(jq -r 'if .exitCode == null then "" else (.exitCode|tostring) end' <<<"$RESULT")"

  echo "AKS command state: ${STATE:-unknown}"

  case "$STATE" in
    Succeeded)
      echo "$RESULT"
      if [[ "$EXIT_CODE" != "0" ]]; then
        echo "AKS command completed with exit code ${EXIT_CODE:-unknown}." >&2
        exit 1
      fi
      exit 0
      ;;
    Failed|Canceled|Cancelled)
      echo "$RESULT"
      exit 1
      ;;
  esac

  sleep 5
done

echo "Timed out waiting for AKS command completion." >&2
exit 1
