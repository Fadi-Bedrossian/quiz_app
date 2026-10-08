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
)

if [[ -n "$FILE_PATH" ]]; then
  invoke_args+=(--file "$FILE_PATH")
fi

set +e
SUBMIT="$(az "${invoke_args[@]}" 2>&1)"
submit_rc=$?
set -e

echo "$SUBMIT"

# Azure CLI currently prints a human-readable submission message for --no-wait,
# for example:
# command id: 0123456789abcdef0123456789abcdef, started at: None, status: Running
COMMAND_ID="$(grep -Eo '[0-9a-fA-F]{32}' <<<"$SUBMIT" | head -n1 || true)"

# Keep JSON compatibility in case a future CLI version returns structured output.
if [[ -z "$COMMAND_ID" ]] && jq -e . >/dev/null 2>&1 <<<"$SUBMIT"; then
  COMMAND_ID="$(jq -r '.id // .commandId // empty' <<<"$SUBMIT")"
fi

if [[ -z "$COMMAND_ID" || "$COMMAND_ID" == "null" ]]; then
  echo "AKS command submission did not return a command id (exit code $submit_rc)." >&2
  exit 1
fi

echo "AKS command id: $COMMAND_ID"

for attempt in $(seq 1 180); do
  set +e
  RESULT="$(az aks command result     --resource-group "$RESOURCE_GROUP"     --name "$AKS_NAME"     --command-id "$COMMAND_ID"     -o json 2>/tmp/aks-command-result.err)"
  rc=$?
  set -e

  if [[ $rc -ne 0 ]]; then
    if [[ $attempt -eq 180 ]]; then
      cat /tmp/aks-command-result.err >&2 || true
      echo "Timed out fetching AKS command result." >&2
      exit 1
    fi
    sleep 5
    continue
  fi

  if ! jq -e . >/dev/null 2>&1 <<<"$RESULT"; then
    echo "Unexpected AKS command result:"
    echo "$RESULT"
    if [[ $attempt -eq 180 ]]; then
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
