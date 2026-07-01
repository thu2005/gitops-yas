#!/usr/bin/env bash
set -euo pipefail

plan_file="${1:-developer-build-plan.tsv}"
target_env="${TARGET_ENV:-dev}"
namespace="yas-${target_env}"

if [[ ! -f "$plan_file" ]]; then
  echo "Plan file not found: $plan_file" >&2
  exit 1
fi

node_address="${NODE_ADDRESS:-}"
if [[ -z "$node_address" ]] && command -v kubectl >/dev/null 2>&1; then
  node_address="$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}' 2>/dev/null || true)"
  if [[ -z "$node_address" ]]; then
    node_address="$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || true)"
  fi
fi
node_address="${node_address:-<worker-node-ip>}"

echo ""
echo "Developer build plan:"
printf "  %-18s %-28s %-12s\n" "SERVICE" "BRANCH" "IMAGE_TAG"
printf "  %-18s %-28s %-12s\n" "-------" "------" "---------"
while IFS=$'\t' read -r service branch image_tag values_file image_key; do
  [[ -n "${service:-}" ]] || continue
  printf "  %-18s %-28s %-12s\n" "$service" "$branch" "$image_tag"
done < "$plan_file"

echo ""
echo "Access URLs after Argo CD sync:"
echo "  Namespace: ${namespace}"
echo "  Node:      ${node_address}"

for svc in storefront-ui backoffice-ui swagger-ui; do
  node_port=""
  if command -v kubectl >/dev/null 2>&1; then
    node_port="$(kubectl get svc "$svc" -n "$namespace" -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || true)"
  fi

  if [[ -n "$node_port" ]]; then
    echo "  ${svc}: http://${node_address}:${node_port}"
  else
    echo "  ${svc}: NodePort not available yet. Wait for Argo CD sync, then run: kubectl get svc ${svc} -n ${namespace}"
  fi
done
