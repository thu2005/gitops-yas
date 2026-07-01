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
node_address="${node_address:-<gke-node-ip>}"

echo ""
echo "Argo CD application:"
echo "  yas-${target_env}"
echo ""
echo "Developer build plan:"
printf "  %-20s %-28s %-12s %-22s\n" "SERVICE" "BRANCH" "IMAGE_TAG" "URL"
printf "  %-20s %-28s %-12s %-22s\n" "-------" "------" "---------" "---"

while IFS=$'\t' read -r svc_name branch image_tag cluster_name values_file values_key argocd_app access_host node_port; do
  [[ -n "${svc_name:-}" ]] || continue
  url="http://${node_address}:${node_port}"
  printf "  %-20s %-28s %-12s %-22s\n" "$svc_name" "$branch" "$image_tag" "$url"
done < "$plan_file"

echo ""
echo "Wait for Argo CD sync, then verify:"
echo "  kubectl get app yas-${target_env} -n argocd"
echo "  kubectl get pods -n ${namespace}"
echo "  kubectl get svc storefront-ui backoffice-ui swagger-ui -n ${namespace}"
