#!/usr/bin/env bash
# Validate required and BM-supported BCP-47 locale filenames in a translations directory.
#
# Usage: validate-locale-files.sh <translations-dir> [label]
#
# Exit codes:
#   0 - all required locale files are present and filenames are valid
#   1 - required locale files are missing or filenames are misformatted
#   2 - usage or required-locale configuration error

set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: $(basename "$0") <translations-dir> [label]" >&2
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
required_locales_file="${REQUIRED_BM_LOCALES_FILE:-$SCRIPT_DIR/../config/required-bm-locales.txt}"
translations_dir="$1"
label="${2:-Translations directory}"

if [[ ! -d "$translations_dir" ]]; then
  echo "$label not found: $translations_dir" >&2
  exit 2
fi

if [[ ! -f "$required_locales_file" ]]; then
  echo "Required BM locale configuration not found: $required_locales_file" >&2
  exit 2
fi

missing_locales=()
required_has_en_us=false
while IFS= read -r locale || [[ -n "$locale" ]]; do
  locale="${locale%$'\r'}"
  [[ -z "$locale" ]] && continue
  if [[ ! "$locale" =~ ^[a-z]{2}(-[A-Z]{2})?$ ]]; then
    echo "Required BM locale configuration contains misformatted locale: $locale" >&2
    exit 2
  fi
  [[ "$locale" == "en-US" ]] && required_has_en_us=true
  if [[ ! -f "$translations_dir/$locale.json" ]]; then
    missing_locales+=("$locale.json")
  fi
done < "$required_locales_file"

if [[ "$required_has_en_us" == "false" ]]; then
  echo "Required BM locale configuration must include en-US" >&2
  exit 2
fi

misformatted_locales=()
while IFS= read -r locale_file; do
  filename="$(basename "$locale_file")"
  if [[ ! "$filename" =~ ^[a-z]{2}(-[A-Z]{2})?\.json$ ]]; then
    misformatted_locales+=("$filename")
  fi
done < <(find "$translations_dir" -mindepth 1 -maxdepth 1 -type f -name '*.json' | sort)

validation_failed=false
if [[ ${#missing_locales[@]} -gt 0 ]]; then
  echo "$label is missing required locale file(s): ${missing_locales[*]}" >&2
  validation_failed=true
fi

if [[ ${#misformatted_locales[@]} -gt 0 ]]; then
  echo "$label contains misformatted locale file(s): ${misformatted_locales[*]} (expected BM-supported BCP-47 filename such as de.json or en-US.json)" >&2
  validation_failed=true
fi

if [[ "$validation_failed" == "true" ]]; then
  exit 1
fi

locale_count="$(find "$translations_dir" -mindepth 1 -maxdepth 1 -type f -name '*.json' | wc -l | tr -d ' ')"
echo "$label locale files are valid ($locale_count file(s))"
