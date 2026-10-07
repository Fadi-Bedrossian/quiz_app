#!/usr/bin/env bash
set -euo pipefail

LOCATION="${1:-northeurope}"

# Two-vCPU SKUs from the families Azure reports as eligible for this subscription.
# Prefer the smaller non-data-disk variants first.
CANDIDATES=(
  Standard_DC2as_v6
  Standard_EC2as_v5
  Standard_EC2as_v6
  Standard_DC2ads_v6
  Standard_EC2ads_v5
  Standard_EC2ads_v6
)

echo "Checking AKS VM SKU availability and quota in ${LOCATION}..." >&2

SKUS_JSON="$(az vm list-skus   --location "$LOCATION"   --resource-type virtualMachines   --all   -o json)"

USAGE_JSON="$(az vm list-usage   --location "$LOCATION"   -o json)"

TOTAL_CURRENT="$(jq -r '[.[] | select((.name.value | ascii_downcase) == "cores")][0].currentValue // 0' <<<"$USAGE_JSON")"
TOTAL_LIMIT="$(jq -r '[.[] | select((.name.value | ascii_downcase) == "cores")][0].limit // 0' <<<"$USAGE_JSON")"
TOTAL_REMAINING=$((TOTAL_LIMIT - TOTAL_CURRENT))

for SKU in "${CANDIDATES[@]}"; do
  ITEM="$(jq -c --arg sku "$SKU" '[.[] | select((.name | ascii_downcase) == ($sku | ascii_downcase))][0] // empty' <<<"$SKUS_JSON")"

  if [ -z "$ITEM" ]; then
    echo "Skipping $SKU: SKU not returned for $LOCATION." >&2
    continue
  fi

  RESTRICTIONS="$(jq -r '.restrictions | length' <<<"$ITEM")"
  if [ "$RESTRICTIONS" -gt 0 ]; then
    echo "Skipping $SKU: restricted for this subscription/location." >&2
    continue
  fi

  FAMILY="$(jq -r '.family // empty' <<<"$ITEM")"
  VCPUS="$(jq -r '[.capabilities[]? | select(.name == "vCPUs")][0].value // "0"' <<<"$ITEM")"

  if [ -z "$FAMILY" ] || [ "$VCPUS" = "0" ]; then
    echo "Skipping $SKU: unable to determine family/vCPU count." >&2
    continue
  fi

  FAMILY_CURRENT="$(jq -r --arg family "$FAMILY" '[.[] | select((.name.value | ascii_downcase) == ($family | ascii_downcase))][0].currentValue // empty' <<<"$USAGE_JSON")"
  FAMILY_LIMIT="$(jq -r --arg family "$FAMILY" '[.[] | select((.name.value | ascii_downcase) == ($family | ascii_downcase))][0].limit // empty' <<<"$USAGE_JSON")"

  if [ -z "$FAMILY_CURRENT" ] || [ -z "$FAMILY_LIMIT" ]; then
    echo "Skipping $SKU: no quota record found for $FAMILY." >&2
    continue
  fi

  FAMILY_REMAINING=$((FAMILY_LIMIT - FAMILY_CURRENT))
  echo "$SKU -> family=$FAMILY, vCPUs=$VCPUS, family remaining=$FAMILY_REMAINING, regional remaining=$TOTAL_REMAINING" >&2

  if [ "$FAMILY_REMAINING" -ge "$VCPUS" ] && [ "$TOTAL_REMAINING" -ge "$VCPUS" ]; then
    echo "$SKU"
    exit 0
  fi
done

echo "No eligible 2-vCPU AKS VM size has enough quota in $LOCATION." >&2
echo "Current VM-family quotas:" >&2
az vm list-usage   --location "$LOCATION"   --query "[?contains(name.localizedValue, 'Family')].[name.localizedValue,currentValue,limit]"   -o table >&2 || true
exit 1
