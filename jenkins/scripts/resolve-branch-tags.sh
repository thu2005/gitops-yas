#!/usr/bin/env bash
set -euo pipefail

source_repo_url="${SOURCE_REPO_URL:-https://github.com/thu2005/yas.git}"
target_env="${TARGET_ENV:-dev}"
output_file="${1:-developer-build-plan.tsv}"
values_file="helm/yas/values-${target_env}.yaml"
argocd_app="yas-${target_env}"
cluster_name="gke"

normalize_branch() {
  local branch="${1:-main}"
  branch="${branch#"${branch%%[![:space:]]*}"}"
  branch="${branch%"${branch##*[![:space:]]}"}"
  branch="${branch#refs/heads/}"
  branch="${branch#origin/}"
  [[ -n "$branch" ]] || branch="main"
  printf '%s' "$branch"
}

resolve_tag() {
  local branch="$1"
  if [[ "$branch" == "main" || "$branch" == "latest" ]]; then
    printf '%s' "$branch"
    return
  fi

  local commit
  commit="$(git ls-remote "$source_repo_url" "refs/heads/$branch" | awk '{print $1}')"
  if [[ -z "$commit" ]]; then
    echo "ERROR: Cannot resolve branch '$branch' from $source_repo_url" >&2
    exit 1
  fi

  printf '%s' "${commit:0:8}"
}

branch_value() {
  local env_name="$1"
  printf '%s' "${!env_name:-main}"
}

write_service() {
  local service_name="$1"
  local branch_env="$2"
  local values_key="$3"
  local node_port="$4"
  local branch
  local image_tag

  branch="$(normalize_branch "$(branch_value "$branch_env")")"
  image_tag="$(resolve_tag "$branch")"

  if [[ ! -f "$values_file" ]]; then
    echo "ERROR: Missing values file: $values_file" >&2
    exit 1
  fi

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$service_name" "$branch" "$image_tag" "$cluster_name" "$values_file" \
    "$values_key" "$argocd_app" "nodeport" "$node_port" >> "$output_file"
}

printf '' > "$output_file"

write_service "product-service"    "PRODUCT_SERVICE_BRANCH"   "product"       "30005"
write_service "cart-service"       "CART_SERVICE_BRANCH"      "cart"          "30008"
write_service "order-service"      "ORDER_SERVICE_BRANCH"     "order"         "30009"
write_service "customer-service"   "CUSTOMER_SERVICE_BRANCH"  "customer"      "30007"
write_service "inventory-service"  "INVENTORY_SERVICE_BRANCH" "inventory"     "30010"
write_service "location-service"   "LOCATION_SERVICE_BRANCH"  "location"      "30015"
write_service "tax-service"        "TAX_SERVICE_BRANCH"       "tax"           "30011"
write_service "media-service"      "MEDIA_SERVICE_BRANCH"     "media"         "30006"
write_service "payment-service"    "PAYMENT_SERVICE_BRANCH"   "payment"       "30016"
write_service "search-service"     "SEARCH_SERVICE_BRANCH"    "search"        "30012"
write_service "storefront-bff"     "STOREFRONT_BFF_BRANCH"    "storefront-bff" "30002"
write_service "storefront-ui"      "STOREFRONT_UI_BRANCH"     "storefront-ui"  "30001"
write_service "backoffice-bff"     "BACKOFFICE_BFF_BRANCH"    "backoffice-bff" "30004"
write_service "backoffice-ui"      "BACKOFFICE_UI_BRANCH"     "backoffice-ui"  "30003"
write_service "sampledata"         "SAMPLEDATA_BRANCH"        "sampledata"     "30013"

echo "Resolved developer build plan:"
column -t -s $'\t' "$output_file" 2>/dev/null || cat "$output_file"
