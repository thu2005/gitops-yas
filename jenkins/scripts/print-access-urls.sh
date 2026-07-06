#!/usr/bin/env bash
set -euo pipefail

plan_file="${1:-developer-build-plan.tsv}"
target_env="${TARGET_ENV:-dev}"
namespace="yas-${target_env}"
default_node_address="${DEFAULT_NODE_ADDRESS:-34.139.231.192}"
default_ingress_address="${DEFAULT_INGRESS_ADDRESS:-35.190.132.23}"
default_gateway_node_port="${DEFAULT_GATEWAY_NODE_PORT:-30890}"

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

gateway_node_port="${GATEWAY_NODE_PORT:-}"
if [[ -z "$gateway_node_port" ]] && command -v kubectl >/dev/null 2>&1; then
  gateway_node_port="$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.spec.ports[?(@.port==80)].nodePort}' 2>/dev/null || true)"
fi
gateway_node_port="${gateway_node_port:-$default_gateway_node_port}"

echo ""
echo "Argo CD application:"
echo "  yas-${target_env}"
echo ""
echo "Demo web URLs:"
echo "  Storefront: http://storefront.yas.local:${gateway_node_port}"
echo "  Backoffice: http://backoffice.yas.local:${gateway_node_port}"
echo "  Swagger UI: http://swagger.yas.local:${gateway_node_port}"
echo ""
echo "Hosts entries for demo web URLs:"
echo "  ${node_address} identity.yas.local"
echo "  ${node_address} storefront.yas.local"
echo "  ${node_address} backoffice.yas.local"
echo "  ${node_address} swagger.yas.local"
echo ""
echo "Istio LoadBalancer URLs:"
echo "  Storefront: http://storefront.yas.local"
echo "  Backoffice: http://backoffice.yas.local"
echo "  Swagger UI: http://swagger.yas.local"
echo "  hosts IP: ${ingress_address}"
echo ""
echo "NodePort host for service URLs:"
echo "  ${node_address}"
echo ""
echo "Note:"
echo "  The demo web URLs use the Istio ingressgateway NodePort (${gateway_node_port}) on the worker node."
echo "  Raw service NodePorts are printed as Kubernetes evidence, but direct browser access can be blocked by Istio mTLS/RBAC."
echo ""
echo "Developer build plan:"
printf "  %-20s %-28s %-12s %-34s\n" "SERVICE" "BRANCH" "IMAGE_TAG" "TEST_URL"
printf "  %-20s %-28s %-12s %-34s\n" "-------" "------" "---------" "--------"

while IFS=$'\t' read -r svc_name branch image_tag cluster_name values_file values_key argocd_app access_host node_port; do
  [[ -n "${svc_name:-}" ]] || continue
  case "$svc_name" in
    storefront-ui)
      url="http://storefront.yas.local:${gateway_node_port}"
      ;;
    backoffice-ui)
      url="http://backoffice.yas.local:${gateway_node_port}"
      ;;
    *)
      url="http://swagger.yas.local:${gateway_node_port}"
      ;;
  esac
  printf "  %-20s %-28s %-12s %-34s\n" "$svc_name" "$branch" "$image_tag" "$url"
done < "$plan_file"

echo ""
echo "Raw Kubernetes NodePorts:"
printf "  %-20s %-18s\n" "SERVICE" "NODEPORT_URL"
printf "  %-20s %-18s\n" "-------" "------------"
while IFS=$'\t' read -r svc_name branch image_tag cluster_name values_file values_key argocd_app access_host node_port; do
  [[ -n "${svc_name:-}" ]] || continue
  printf "  %-20s http://%s:%s\n" "$svc_name" "$node_address" "$node_port"
done < "$plan_file"

echo ""
echo "Wait for Argo CD sync, then verify:"
echo "  kubectl get app yas-${target_env} -n argocd"
echo "  kubectl get pods -n ${namespace}"
echo "  kubectl get svc storefront-ui backoffice-ui swagger-ui -n ${namespace}"
