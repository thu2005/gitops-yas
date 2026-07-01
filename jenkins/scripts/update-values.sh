#!/usr/bin/env bash
set -euo pipefail

plan_file="${1:-developer-build-plan.tsv}"

if [[ ! -f "$plan_file" ]]; then
  echo "Plan file not found: $plan_file" >&2
  exit 1
fi

update_tag() {
  local values_file="$1"
  local image_key="$2"
  local image_tag="$3"
  local temp_file

  temp_file="$(mktemp)"

  awk -v image_key="$image_key" -v image_tag="$image_tag" '
    BEGIN {
      in_key = 0
      in_image = 0
      updated = 0
    }
    /^[A-Za-z0-9_-]+:[[:space:]]*$/ {
      in_key = ($0 == image_key ":")
      in_image = 0
    }
    in_key && /^[[:space:]]+image:[[:space:]]*$/ {
      in_image = 1
    }
    in_key && in_image && /^[[:space:]]+tag:[[:space:]]*/ {
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
    echo "ERROR: Cannot update ${image_key}.image.tag in ${values_file}" >&2
    exit 1
  }

  mv "$temp_file" "$values_file"
}

while IFS=$'\t' read -r service branch image_tag values_file image_key; do
  [[ -n "${service:-}" ]] || continue
  echo "Updating ${values_file}: ${image_key}.image.tag=${image_tag} (${service}, branch=${branch})"
  update_tag "$values_file" "$image_key" "$image_tag"
done < "$plan_file"

echo "GitOps values diff:"
git diff -- environments/*/services/*.yaml || true
