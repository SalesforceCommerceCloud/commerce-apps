#!/usr/bin/env bash

# Validates manifest readability, JSON shape, and duplicate zip entries.
validate_manifest() {
  local manifest_path="${1:?manifest path is required}"

  if [[ ! -f "$manifest_path" ]]; then
    echo "::error file=$manifest_path::Manifest not found"
    return 1
  fi

  if ! jq -e . "$manifest_path" >/dev/null; then
    echo "::error file=$manifest_path::Manifest is not valid JSON"
    return 1
  fi

  local dup_zips
  dup_zips="$(
    jq -r '
      [
        to_entries[]
        | select(.value | type == "array")
        | .value[]?
        | select(type == "object" and ((.zip // "") != ""))
        | .zip
      ]
      | group_by(.)
      | map(select(length > 1) | .[0])
      | .[]?
    ' "$manifest_path"
  )"

  if [[ -n "$dup_zips" ]]; then
    while IFS= read -r dup; do
      [[ -z "$dup" ]] && continue
      echo "::error file=$manifest_path::Duplicate zip entry found in manifest: $dup"
    done <<< "$dup_zips"
    return 1
  fi
}

# Returns exactly one matching manifest entry JSON object for zip filename.
get_manifest_entry_for_zip() {
  local zip_file="${1:?zip filename is required}"
  local manifest_path="${2:?manifest path is required}"

  local matches
  matches="$(
    jq -c --arg z "$zip_file" '
      [
        to_entries[]
        | select(.value | type == "array")
        | .value[]?
        | select(type == "object" and (.zip? == $z))
      ]
    ' "$manifest_path"
  )"

  local match_count
  match_count="$(jq 'length' <<< "$matches")"

  if [[ "$match_count" -eq 0 ]]; then
    echo "::error file=$manifest_path::No manifest entry found for ZIP $zip_file"
    return 1
  fi
  if [[ "$match_count" -gt 1 ]]; then
    echo "::error file=$manifest_path::Multiple manifest entries found for ZIP $zip_file"
    return 1
  fi

  jq -c '.[0]' <<< "$matches"
}
