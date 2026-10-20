#!/usr/bin/env bash
# Fail if a CAP's Storefront Next extension imports @salesforce/storefront-ui.
#
# Mirrored merchant Storefront Next builds inline UI primitives into
# @/components/ui/... and remove the @salesforce/storefront-ui package.
# Imports from that package resolve in the monorepo but fail Vite/Rollup in
# those merchant builds.
#
# Usage: validate-storefront-imports.sh <cap-root>
#
# Exit codes:
#   0 - no forbidden imports (or no storefront-next/ — Backend-only apps skip)
#   1 - one or more files import @salesforce/storefront-ui (errors on stderr)
#   2 - usage error (bad args or unreadable input)

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

sfnext_dir="$cap_root/storefront-next"

if [[ ! -d "$sfnext_dir" ]]; then
  echo "No storefront-next/ directory - OK (Backend-only app)"
  exit 0
fi

# Match import/require/export-from of @salesforce/storefront-ui (with or without subpath).
# Scans JS/TS source only; ignore lockfiles, JSON, and docs.
matches="$(
  grep -RInE \
    --include='*.ts' --include='*.tsx' --include='*.js' --include='*.jsx' --include='*.mjs' --include='*.cjs' \
    "(from|require\()\s*['\"]@salesforce/storefront-ui(/[^'\"]*)?['\"]" \
    "$sfnext_dir" 2>/dev/null || true
)"

if [[ -n "$matches" ]]; then
  echo "Forbidden @salesforce/storefront-ui import(s) in storefront-next/:" >&2
  echo "Mirrored merchant Storefront Next builds remove that package; use @/components/ui/... instead." >&2
  echo "$matches" >&2
  exit 1
fi

echo "storefront-next/ import check passed (no @salesforce/storefront-ui imports)"
exit 0
