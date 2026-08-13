#!/usr/bin/env bash
# Validate locale filenames in commerce-apps-manifest/translations/.
#
# Usage: validate-registry-translations.sh <translations-dir>
#
# Exit codes:
#   0 - locale filenames are valid
#   1 - one or more locale filenames are unsupported
#   2 - usage error (bad args or missing directory)

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $(basename "$0") <translations-dir>" >&2
  exit 2
fi

translations_dir="$1"

if [[ ! -d "$translations_dir" ]]; then
  echo "Registry translations directory not found: $translations_dir" >&2
  exit 2
fi

# Set of supported manifest locales. Region separators use BCP-47 dash form.
SUPPORTED_LOCALES=("ar-MA" "de" "en-US" "es" "fr" "it" "ja" "ko" "nl" "pl" "pt" "zh-CN" "zh-TW")

unsupported_locales=()
while IFS= read -r locale_file; do
  locale="$(basename "$locale_file" .json)"
  supported_locale=false
  for supported in "${SUPPORTED_LOCALES[@]}"; do
    if [[ "$locale" == "$supported" ]]; then
      supported_locale=true
      break
    fi
  done
  [[ "$supported_locale" == "false" ]] && unsupported_locales+=("$locale")
done < <(find "$translations_dir" -mindepth 1 -maxdepth 1 -type f -name '*.json' | sort)

if [[ ${#unsupported_locales[@]} -gt 0 ]]; then
  echo "Unsupported registry translation locale file(s): ${unsupported_locales[*]} (supported: ${SUPPORTED_LOCALES[*]}; use BCP-47 dash form for region separators)" >&2
  exit 1
fi

locale_count="$(find "$translations_dir" -mindepth 1 -maxdepth 1 -type f -name '*.json' | wc -l | tr -d ' ')"
echo "Registry translation locale filenames are valid ($locale_count file(s))"
