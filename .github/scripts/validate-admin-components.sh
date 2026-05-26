#!/usr/bin/env bash
# Validate the shape of an app-configuration/adminComponents.json file.
#
# Usage: validate-admin-components.sh <path-to-adminComponents.json>
#
# Exit codes:
#   0 - file is valid (or arguments accepted)
#   1 - file is invalid (errors printed to stderr)
#   2 - usage error (bad args or unreadable file)
#
# Schema:
#   - Top-level must be a JSON object.
#   - Top-level keys "connectionDetails" and "configuration" are both
#     optional. When present, each must be an array.
#   - Every entry in either array must be an object with a non-empty string
#     "type". Other fields are not validated for connectionDetails entries.
#   - Every entry in configuration[] must additionally declare a non-empty
#     string "componentKey" matching ^[a-z][a-z0-9_]*$. componentKey values
#     must be unique within configuration[] (the namespace is flat in
#     translation files).
#   - Configuration entries with type == "storefrontComponentVisibility"
#     must declare attributes[] (non-empty array). Each attribute must be
#     an object with a non-empty string "id", non-empty string "label",
#     and boolean "defaultValue".

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $(basename "$0") <path-to-adminComponents.json>" >&2
  exit 2
fi

file="$1"

if [[ ! -f "$file" ]]; then
  echo "File not found: $file" >&2
  exit 2
fi

if ! jq empty "$file" 2>/dev/null; then
  echo "adminComponents.json is not valid JSON" >&2
  exit 1
fi

errors="$(jq -r '
  def validate_attribute($cidx; $aidx):
    if (. | type) != "object" then
      "configuration[\($cidx)].attributes[\($aidx)]: must be an object"
    elif (.id | type) != "string" or (.id | length) == 0 then
      "configuration[\($cidx)].attributes[\($aidx)]: \"id\" is required and must be a non-empty string"
    elif (.label | type) != "string" or (.label | length) == 0 then
      "configuration[\($cidx)].attributes[\($aidx)]: \"label\" is required and must be a non-empty string"
    elif (.defaultValue | type) != "boolean" then
      "configuration[\($cidx)].attributes[\($aidx)]: \"defaultValue\" is required and must be a boolean"
    else empty end;

  def validate_entry($section; $idx):
    if (. | type) != "object" then
      "\($section)[\($idx)]: must be an object"
    elif (.type | type) != "string" or (.type | length) == 0 then
      "\($section)[\($idx)]: \"type\" is required and must be a non-empty string"
    else
      ([
        # componentKey is required on configuration[] entries only.
        (if $section == "configuration" then
           if (.componentKey | type) != "string" or (.componentKey | length) == 0 then
             "\($section)[\($idx)]: \"componentKey\" is required and must be a non-empty string"
           elif (.componentKey | test("^[a-z][a-z0-9_]*$")) | not then
             "\($section)[\($idx)]: \"componentKey\" must match ^[a-z][a-z0-9_]*$ (snake_case, got \"\(.componentKey)\")"
           else empty end
         else empty end),
        # storefrontComponentVisibility requires a non-empty attributes array.
        (if $section == "configuration" and .type == "storefrontComponentVisibility" then
           if (.attributes | type) != "array" or (.attributes | length) == 0 then
             "\($section)[\($idx)]: storefrontComponentVisibility requires non-empty \"attributes\" array"
           else
             ([.attributes | to_entries[] as $e | ($e.value | validate_attribute($idx; $e.key))] | join("\n") | select(length > 0))
           end
         else empty end)
      ] | map(select(. != null and . != "")) | join("\n") | select(length > 0))
    end;

  def validate_section($section):
    if has($section) then
      (if (.[$section] | type) != "array" then
         "\"\($section)\" must be an array"
       else
         (.[$section] | to_entries[] as $e | ($e.value | validate_entry($section; $e.key)))
       end)
    else empty end;

  if (. | type) != "object" then
    "adminComponents.json must be a JSON object"
  else
    ([validate_section("connectionDetails"), validate_section("configuration")] | join("\n"))
  end
' "$file" 2>/dev/null)"

if [[ -n "$errors" ]]; then
  echo "adminComponents.json structure validation failed:" >&2
  printf '%s\n' "$errors" >&2
  exit 1
fi

# componentKey uniqueness check (within configuration[]).
duplicate_keys="$(jq -r '
  [(.configuration // [])[] | select(has("componentKey")) | .componentKey]
  | group_by(.) | map(select(length > 1) | .[0]) | join(", ")
' "$file" 2>/dev/null)"
if [[ -n "$duplicate_keys" ]]; then
  echo "adminComponents.json has duplicate componentKey values in configuration[]: $duplicate_keys" >&2
  exit 1
fi

cd_count="$(jq '(.connectionDetails // []) | length' "$file")"
cfg_count="$(jq '(.configuration // []) | length' "$file")"
echo "adminComponents.json is valid (connectionDetails=$cd_count, configuration=$cfg_count)"
exit 0
