#!/usr/bin/env bash
# Validate the shape of app-configuration/translations/ inside a CAP root.
#
# Usage: validate-translations.sh <cap-root>
#
# Exit codes:
#   0 - translations are valid (or directory is absent — it's optional)
#   1 - translations are invalid (errors printed to stderr)
#   2 - usage error (bad args or unreadable input)
#
# Schema:
#   - Locale filenames must be in the supported set (kept in sync with the
#     "Supported locales" table in CONTRIBUTING.md).
#   - en-US.json is required when the directory exists.
#   - Each locale file must be a JSON object with a "tasks" object whose
#     entries each have non-empty "name" and "description" strings.
#     Optional "adminComponents" object holds per-component "attributes"
#     with non-empty "label" strings.
#   - tasksList.json taskKeys must all appear in en-US.json's "tasks".
#   - Non-default locales must have the same task key set as en-US.json.
#   - When adminComponents.json is present, every (componentKey,
#     attribute id) pair must appear in en-US.json's adminComponents and
#     all non-default locales must match en-US.json's pair set exactly.

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $(basename "$0") <cap-root>" >&2
  exit 2
fi

cap_root="$1"

if [[ ! -d "$cap_root" ]]; then
  echo "CAP root not found: $cap_root" >&2
  exit 2
fi

# Set of supported BM locales — must match the table in CONTRIBUTING.md
# under "Localizing app-shipped strings > Supported locales".
SUPPORTED_LOCALES=("ar_MA" "de" "en-US" "es" "fr" "it" "ja" "ko" "nl" "pl" "pt" "zh_CN" "zh_TW")

translations_dir="$cap_root/app-configuration/translations"

if [[ ! -d "$translations_dir" ]]; then
  echo "No app-configuration/translations/ - OK (optional)"
  exit 0
fi

default_locale="$translations_dir/en-US.json"
if [[ ! -f "$default_locale" ]]; then
  echo "app-configuration/translations/ exists but en-US.json is missing" >&2
  exit 1
fi

# Validate per-file shape.
shape_errors=""
while IFS= read -r locale_file; do
  if ! jq empty "$locale_file" 2>/dev/null; then
    shape_errors+=$'\n'"$(basename "$locale_file"): not valid JSON"
    continue
  fi
  if ! jq -e '.tasks | type == "object"' "$locale_file" >/dev/null 2>&1; then
    shape_errors+=$'\n'"$(basename "$locale_file"): missing or non-object \"tasks\" key"
    continue
  fi
  bad_entries="$(jq -r '
    .tasks
    | to_entries
    | map(select(
        (.value | type) != "object"
        or (.value.name | type) != "string" or (.value.name | length) == 0
        or (.value.description | type) != "string" or (.value.description | length) == 0
      ) | .key)
    | join(", ")
  ' "$locale_file" 2>/dev/null)"
  if [[ -n "$bad_entries" ]]; then
    shape_errors+=$'\n'"$(basename "$locale_file"): tasks with missing/invalid name or description: $bad_entries"
  fi

  if jq -e 'has("adminComponents")' "$locale_file" >/dev/null 2>&1; then
    if ! jq -e '.adminComponents | type == "object"' "$locale_file" >/dev/null 2>&1; then
      shape_errors+=$'\n'"$(basename "$locale_file"): \"adminComponents\" must be an object"
      continue
    fi
    bad_admin="$(jq -r '
      .adminComponents
      | to_entries
      | map(
          .key as $ck |
          (.value | (
            if type != "object" then "\($ck): must be an object"
            elif has("attributes") | not then "\($ck): missing \"attributes\""
            elif (.attributes | type) != "object" then "\($ck): \"attributes\" must be an object"
            else
              (.attributes | to_entries | map(
                select(
                  (.value | type) != "object"
                  or (.value.label | type) != "string"
                  or (.value.label | length) == 0
                ) | "\($ck).attributes.\(.key): \"label\" missing or invalid"
              ) | join("; "))
            end
          ))
        )
      | map(select(. != null and . != ""))
      | join("; ")
    ' "$locale_file" 2>/dev/null)"
    if [[ -n "$bad_admin" ]]; then
      shape_errors+=$'\n'"$(basename "$locale_file"): adminComponents shape invalid: $bad_admin"
    fi
  fi
done < <(find "$translations_dir" -mindepth 1 -maxdepth 1 -type f -name '*.json')

if [[ -n "$shape_errors" ]]; then
  echo "app-configuration/translations/ shape validation failed:$shape_errors" >&2
  exit 1
fi

# Locale filenames must be in the supported set.
unsupported_locales=()
while IFS= read -r locale_file; do
  fname="$(basename "$locale_file" .json)"
  ok=false
  for supported in "${SUPPORTED_LOCALES[@]}"; do
    [[ "$fname" == "$supported" ]] && ok=true && break
  done
  [[ "$ok" == "false" ]] && unsupported_locales+=("$fname")
done < <(find "$translations_dir" -mindepth 1 -maxdepth 1 -type f -name '*.json')

if [[ ${#unsupported_locales[@]} -gt 0 ]]; then
  echo "Unsupported locale file(s) in app-configuration/translations/: ${unsupported_locales[*]} (supported: ${SUPPORTED_LOCALES[*]})" >&2
  exit 1
fi

# tasksList.json taskKey coverage in en-US.json.
tasks_list="$cap_root/app-configuration/tasksList.json"
if [[ -f "$tasks_list" ]]; then
  missing_in_en="$(jq -r --argjson en "$(jq '.tasks | keys' "$default_locale")" \
    '[.[] | .taskKey] - $en | join(", ")' "$tasks_list" 2>/dev/null)"
  if [[ -n "$missing_in_en" ]]; then
    echo "tasksList.json references taskKey(s) not present in translations/en-US.json: $missing_in_en" >&2
    exit 1
  fi
fi

# Non-default locales must share en-US's task key set exactly.
en_keys_sorted="$(jq -r '.tasks | keys_unsorted | sort | join(",")' "$default_locale")"
while IFS= read -r locale_file; do
  [[ "$locale_file" == "$default_locale" ]] && continue
  locale_keys_sorted="$(jq -r '.tasks | keys_unsorted | sort | join(",")' "$locale_file")"
  if [[ "$locale_keys_sorted" != "$en_keys_sorted" ]]; then
    extra_in_locale="$(jq -r --argjson en "$(jq '.tasks | keys' "$default_locale")" \
      '(.tasks | keys) - $en | join(", ")' "$locale_file")"
    missing_in_locale="$(jq -r --argjson locale "$(jq '.tasks | keys' "$locale_file")" \
      '(.tasks | keys) - $locale | join(", ")' "$default_locale")"
    msg="$(basename "$locale_file") tasks key parity mismatch with en-US.json"
    [[ -n "$missing_in_locale" ]] && msg+=" — missing: $missing_in_locale"
    [[ -n "$extra_in_locale" ]] && msg+=" — extra: $extra_in_locale"
    echo "$msg" >&2
    exit 1
  fi
done < <(find "$translations_dir" -mindepth 1 -maxdepth 1 -type f -name '*.json')

# adminComponents coverage + parity (only when adminComponents.json is shipped).
admin_components="$cap_root/app-configuration/adminComponents.json"
if [[ -f "$admin_components" ]]; then
  cap_pairs_sorted="$(jq -r '
    [.configuration // []
      | .[]
      | select(has("componentKey") and (.attributes | type) == "array")
      | .componentKey as $ck
      | .attributes[]
      | "\($ck)/\(.id)"]
    | sort | join(",")
  ' "$admin_components")"

  flatten_admin() {
    local f="$1"
    jq -r '
      (.adminComponents // {})
      | to_entries
      | map(.key as $ck | (.value.attributes // {}) | keys | map("\($ck)/\(.)"))
      | flatten | sort | join(",")
    ' "$f"
  }

  en_admin_pairs="$(flatten_admin "$default_locale")"
  missing_in_en_admin="$(comm -23 \
    <(printf '%s\n' "$cap_pairs_sorted" | tr ',' '\n' | grep -v '^$') \
    <(printf '%s\n' "$en_admin_pairs" | tr ',' '\n' | grep -v '^$') | tr '\n' ',' | sed 's/,$//')"
  if [[ -n "$missing_in_en_admin" ]]; then
    echo "adminComponents.json references componentKey/attribute pair(s) not present in translations/en-US.json: $missing_in_en_admin" >&2
    exit 1
  fi

  while IFS= read -r locale_file; do
    [[ "$locale_file" == "$default_locale" ]] && continue
    locale_admin_pairs="$(flatten_admin "$locale_file")"
    if [[ "$locale_admin_pairs" != "$en_admin_pairs" ]]; then
      extra="$(comm -23 \
        <(printf '%s\n' "$locale_admin_pairs" | tr ',' '\n' | grep -v '^$') \
        <(printf '%s\n' "$en_admin_pairs" | tr ',' '\n' | grep -v '^$') | tr '\n' ',' | sed 's/,$//')"
      missing="$(comm -23 \
        <(printf '%s\n' "$en_admin_pairs" | tr ',' '\n' | grep -v '^$') \
        <(printf '%s\n' "$locale_admin_pairs" | tr ',' '\n' | grep -v '^$') | tr '\n' ',' | sed 's/,$//')"
      msg="$(basename "$locale_file") adminComponents key parity mismatch with en-US.json"
      [[ -n "$missing" ]] && msg+=" — missing: $missing"
      [[ -n "$extra" ]] && msg+=" — extra: $extra"
      echo "$msg" >&2
      exit 1
    fi
  done < <(find "$translations_dir" -mindepth 1 -maxdepth 1 -type f -name '*.json')
fi

locale_count="$(find "$translations_dir" -mindepth 1 -maxdepth 1 -type f -name '*.json' | wc -l | tr -d ' ')"
echo "translations/ is valid ($locale_count locale file(s))"
exit 0
