#!/usr/bin/env bash
set -euo pipefail

plan_file="${1:-developer-build-plan.tsv}"
target_env="${TARGET_ENV:-dev}"
namespace="yas-${target_env}"
default_node_address="${DEFAULT_NODE_ADDRESS:-34.139.231.192}"
default_ingress_address="${DEFAULT_INGRESS_ADDRESS:-35.190.132.23}"
swagger_ui_tag="${SWAGGER_UI_TAG:-v5.17.14}"

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
node_address="${node_address:-$default_node_address}"

ingress_address="${INGRESS_ADDRESS:-}"
if [[ -z "$ingress_address" ]] && command -v kubectl >/dev/null 2>&1; then
  ingress_address="$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"
fi
ingress_address="${ingress_address:-$default_ingress_address}"

echo ""
echo "Argo CD application:"
echo "  yas-${target_env}"
echo ""
echo "NodePort host for service URLs:"
echo "  ${node_address}"
echo ""
echo "Hosts entries for developer testing:"
echo "  ${node_address} yas.${target_env}.local"
echo "  ${node_address} storefront.yas.local"
echo "  ${node_address} backoffice.yas.local"
echo "  ${node_address} swagger.yas.local"
echo ""
echo "Developer build plan:"
printf "  %-20s %-28s %-12s %-34s\n" "SERVICE" "BRANCH" "IMAGE_TAG" "NODEPORT_URL"
printf "  %-20s %-28s %-12s %-34s\n" "-------" "------" "---------" "------------"

while IFS=$'\t' read -r svc_name branch image_tag cluster_name values_file values_key argocd_app access_host node_port; do
  [[ -n "${svc_name:-}" ]] || continue
  url="http://${node_address}:${node_port}"
  printf "  %-20s %-28s %-12s %-34s\n" "$svc_name" "$branch" "$image_tag" "$url"
done < "$plan_file"

if ! awk -F '\t' '$1 == "swagger-ui" { found = 1 } END { exit found ? 0 : 1 }' "$plan_file"; then
  printf "  %-20s %-28s %-12s %-34s\n" "swagger-ui" "static" "$swagger_ui_tag" "http://${node_address}:30014"
fi

echo ""
echo "Domain name:port examples:"
printf "  %-20s %-34s\n" "SERVICE" "DOMAIN_URL"
printf "  %-20s %-34s\n" "-------" "----------"
while IFS=$'\t' read -r svc_name branch image_tag cluster_name values_file values_key argocd_app access_host node_port; do
  [[ -n "${svc_name:-}" ]] || continue
  printf "  %-20s http://yas.%s.local:%s\n" "$svc_name" "$target_env" "$node_port"
done < "$plan_file"

if ! awk -F '\t' '$1 == "swagger-ui" { found = 1 } END { exit found ? 0 : 1 }' "$plan_file"; then
  printf "  %-20s http://yas.%s.local:%s\n" "swagger-ui" "$target_env" "30014"
fi

echo ""
echo "Demo web pages:"
echo "  Storefront: http://${node_address}:30001"
echo "  Backoffice: http://${node_address}:30003"
echo "  Swagger UI: http://${node_address}:30014"
echo ""
echo "Istio demo URLs, after manually enabling sidecar injection:"
echo "  Storefront: http://storefront.yas.local"
echo "  Backoffice: http://backoffice.yas.local"
echo "  Swagger UI: http://swagger.yas.local"
echo "  hosts IP: ${ingress_address}"

echo ""
echo "Wait for Argo CD sync, then verify:"
echo "  kubectl get app yas-${target_env} -n argocd"
echo "  kubectl get pods -n ${namespace}"
echo "  kubectl get svc storefront-ui backoffice-ui swagger-ui -n ${namespace}"
