#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-yas-dev}"
SERVICE_URL="${SERVICE_URL:-http://product/product/api/v1/products}"
ALLOWED_POD="${ALLOWED_POD:-curl-order}"
DENIED_POD="${DENIED_POD:-curl-unauthorized}"
ALLOWED_EXPECTED_STATUS="${ALLOWED_EXPECTED_STATUS:-401}"
DENIED_EXPECTED_STATUS="${DENIED_EXPECTED_STATUS:-403}"
TIMEOUT="${TIMEOUT:-120s}"
KEEP_PODS="${KEEP_PODS:-false}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cleanup() {
  if [[ "${KEEP_PODS}" == "true" ]]; then
    return
  fi

  kubectl delete -f "${SCRIPT_DIR}/curl-order-pod.yaml" --ignore-not-found=true >/dev/null 2>&1 || true
  kubectl delete -f "${SCRIPT_DIR}/curl-unauthorized-pod.yaml" --ignore-not-found=true >/dev/null 2>&1 || true
}

wait_for_pod() {
  local pod_name="$1"

  kubectl wait \
    --for=condition=Ready \
    "pod/${pod_name}" \
    -n "${NAMESPACE}" \
    --timeout="${TIMEOUT}"
}

curl_status_from_pod() {
  local pod_name="$1"

  kubectl exec "${pod_name}" -n "${NAMESPACE}" -c curl -- \
    curl -sS -o /tmp/authz-response-body -D /tmp/authz-response-headers -w "%{http_code}" \
    "${SERVICE_URL}"
}

print_response_from_pod() {
  local pod_name="$1"

  echo "----- ${pod_name}: response headers -----"
  kubectl exec "${pod_name}" -n "${NAMESPACE}" -c curl -- sh -c "cat /tmp/authz-response-headers 2>/dev/null || true"
  echo "----- ${pod_name}: response body -----"
  kubectl exec "${pod_name}" -n "${NAMESPACE}" -c curl -- sh -c "cat /tmp/authz-response-body 2>/dev/null || true"
  echo
}

assert_status() {
  local pod_name="$1"
  local expected_status="$2"
  local description="$3"
  local actual_status

  actual_status="$(curl_status_from_pod "${pod_name}")"
  print_response_from_pod "${pod_name}"

  if [[ "${actual_status}" != "${expected_status}" ]]; then
    echo "FAIL: ${description}: expected HTTP ${expected_status}, got HTTP ${actual_status}" >&2
    return 1
  fi

  echo "PASS: ${description}: got HTTP ${actual_status}"
}

trap cleanup EXIT

echo "Applying curl test pods in namespace ${NAMESPACE}..."
kubectl apply -f "${SCRIPT_DIR}/curl-order-pod.yaml"
kubectl apply -f "${SCRIPT_DIR}/curl-unauthorized-pod.yaml"

echo "Waiting for curl test pods to be ready..."
wait_for_pod "${ALLOWED_POD}"
wait_for_pod "${DENIED_POD}"

echo "Testing ${SERVICE_URL}"
assert_status "${ALLOWED_POD}" "${ALLOWED_EXPECTED_STATUS}" "allowed pod ${ALLOWED_POD} can reach the service through Istio"
assert_status "${DENIED_POD}" "${DENIED_EXPECTED_STATUS}" "unauthorized pod ${DENIED_POD} is blocked by Istio"

echo "AuthorizationPolicy connectivity test passed."
