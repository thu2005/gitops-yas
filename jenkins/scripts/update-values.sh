#!/usr/bin/env bash
set -euo pipefail

plan_file="${1:-developer-build-plan.tsv}"

if [[ ! -f "$plan_file" ]]; then
  echo "Plan file not found: $plan_file" >&2
  exit 1
fi

update_tag() {
  local values_file="$1"
  local service_key="$2"
  local image_tag="$3"
  local temp_file

  if [[ ! -f "$values_file" ]]; then
    echo "Values file not found: $values_file" >&2
    exit 1
  fi

  temp_file="$(mktemp)"

  awk -v service_key="$service_key" -v image_tag="$image_tag" '
    BEGIN {
      in_service = 0
      in_image = 0
      updated = 0
    }
    /^[A-Za-z0-9_-]+:[[:space:]]*$/ {
      in_service = ($0 == service_key ":")
      in_image = 0
    }
    in_service && /^[[:space:]]+image:[[:space:]]*$/ {
      in_image = 1
    }
    in_service && in_image && /^[[:space:]]+tag:[[:space:]]*/ {
      sub(/tag:[[:space:]].*/, "tag: " image_tag)
      updated = 1
    }
    { print }
    END {
      if (!updated) {
        exit 42
      }
    }
  ' "$values_file" > "$temp_file" || {
    rm -f "$temp_file"
    echo "Cannot update ${service_key}.image.tag in ${values_file}" >&2
    exit 1
  }

  mv "$temp_file" "$values_file"
}

update_config_revision() {
  local values_file="$1"
  local revision="$2"
  local temp_file

  temp_file="$(mktemp)"

  awk -v revision="$revision" '
    BEGIN {
      in_global = 0
      updated = 0
    }
    /^global:[[:space:]]*$/ {
      in_global = 1
    }
    in_global && /^[[:space:]]+configRevision:[[:space:]]*/ {
      sub(/configRevision:[[:space:]].*/, "configRevision: \"" revision "\"")
      updated = 1
    }
    in_global && /^[A-Za-z0-9_-]+:[[:space:]]*$/ && $0 != "global:" {
      in_global = 0
    }
    { print }
    END {
      if (!updated) {
        exit 42
      }
    }
  ' "$values_file" > "$temp_file" || {
    rm -f "$temp_file"
    echo "Cannot update global.configRevision in ${values_file}" >&2
    exit 1
  }

  mv "$temp_file" "$values_file"
}

rollout_revision="jenkins-${BUILD_NUMBER:-local}"

while IFS=$'\t' read -r service_name branch image_tag cluster_name values_file values_key argocd_app access_host node_port; do
  [[ -z "${service_name:-}" ]] && continue
  echo "Updating ${values_file}: ${values_key}.image.tag=${image_tag} (${service_name}, branch=${branch})"
  update_tag "$values_file" "$values_key" "$image_tag"
  update_config_revision "$values_file" "$rollout_revision"
done < "$plan_file"

echo "GitOps values diff:"
git diff -- helm/yas/values-*.yaml || true
