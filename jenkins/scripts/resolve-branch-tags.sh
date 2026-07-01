#!/usr/bin/env bash
set -euo pipefail

source_repo_url="${SOURCE_REPO_URL:-https://github.com/thu2005/yas.git}"
target_env="${TARGET_ENV:-dev}"
output_file="${1:-developer-build-plan.tsv}"

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
  local service="$1"
  local branch_env="$2"
  local image_key="$3"
  local values_file="environments/${target_env}/services/${service}.yaml"

  local branch
  local image_tag
  branch="$(normalize_branch "$(branch_value "$branch_env")")"
  image_tag="$(resolve_tag "$branch")"

  if [[ ! -f "$values_file" ]]; then
    echo "ERROR: Missing values file: $values_file" >&2
    exit 1
  fi

  printf '%s\t%s\t%s\t%s\t%s\n' \
    "$service" "$branch" "$image_tag" "$values_file" "$image_key" >> "$output_file"
}

printf '' > "$output_file"

write_service "cart"            "TAG_CART"            "backend"
write_service "tax"             "TAG_TAX"             "backend"
write_service "order"           "TAG_ORDER"           "backend"
write_service "product"         "TAG_PRODUCT"         "backend"
write_service "media"           "TAG_MEDIA"           "backend"
write_service "customer"        "TAG_CUSTOMER"        "backend"
write_service "inventory"       "TAG_INVENTORY"       "backend"
write_service "search"          "TAG_SEARCH"          "backend"
write_service "sampledata"      "TAG_SAMPLEDATA"      "backend"
write_service "backoffice-bff"  "TAG_BACKOFFICE_BFF"  "backend"
write_service "storefront-bff"  "TAG_STOREFRONT_BFF"  "backend"
write_service "backoffice-ui"   "TAG_BACKOFFICE_UI"   "ui"
write_service "storefront-ui"   "TAG_STOREFRONT_UI"   "ui"

echo "Resolved developer build plan:"
column -t -s $'\t' "$output_file" 2>/dev/null || cat "$output_file"
