#!/usr/bin/env bash
# Validate locale files in commerce-apps-manifest/translations/.
#
# Usage: validate-registry-translations.sh <translations-dir>
#
# Exit codes:
#   0 - locale files are valid
#   1 - required locale files are missing or filenames are misformatted
#   2 - usage error (bad args or missing directory)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ $# -ne 1 ]]; then
  echo "Usage: $(basename "$0") <translations-dir>" >&2
  exit 2
fi

translations_dir="$1"

if [[ ! -d "$translations_dir" ]]; then
  echo "Registry translations directory not found: $translations_dir" >&2
  exit 2
fi

bash "$SCRIPT_DIR/validate-locale-files.sh" \
  "$translations_dir" \
  "Registry translations directory"
