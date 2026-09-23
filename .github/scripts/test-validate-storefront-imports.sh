#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATE="$SCRIPT_DIR/validate-storefront-imports.sh"

PASS=0
FAIL=0
TMPDIR_ROOT=""
cleanup() { [[ -n "$TMPDIR_ROOT" ]] && rm -rf "$TMPDIR_ROOT"; }
trap cleanup EXIT
TMPDIR_ROOT="$(mktemp -d)"

LAST_OUTPUT=""
LAST_RC=0

run_validate() {
  local cap_root="$1"
  LAST_RC=0
  LAST_OUTPUT="$(bash "$VALIDATE" "$cap_root" 2>&1)" || LAST_RC=$?
  LAST_RC=${LAST_RC:-0}
}

assert_passes() {
  local desc="$1"; local cap_root="$2"
  run_validate "$cap_root"
  if [[ "$LAST_RC" -eq 0 ]]; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc (expected exit 0, got $LAST_RC)"
    echo "    output: $LAST_OUTPUT"
    FAIL=$((FAIL + 1))
  fi
}

assert_rejects() {
  local desc="$1"; local cap_root="$2"; local expect_substr="$3"
  run_validate "$cap_root"
  if [[ "$LAST_RC" -ne 1 ]]; then
    echo "  FAIL: $desc (expected exit 1, got $LAST_RC)"
    echo "    output: $LAST_OUTPUT"
    FAIL=$((FAIL + 1))
    return
  fi
  if [[ "$LAST_OUTPUT" != *"$expect_substr"* ]]; then
    echo "  FAIL: $desc (output missing expected substring)"
    echo "    expected substring: $expect_substr"
    echo "    actual output:      $LAST_OUTPUT"
    FAIL=$((FAIL + 1))
    return
  fi
  echo "  PASS: $desc"
  PASS=$((PASS + 1))
}

echo "=== storefront-ui import validator tests ==="

# --- Passing shapes ---------------------------------------------------

case_dir="$TMPDIR_ROOT/no-storefront"
mkdir -p "$case_dir/cartridges"
assert_passes "no storefront-next/ directory (Backend-only app)" "$case_dir"

case_dir="$TMPDIR_ROOT/allowed-aliases"
mkdir -p "$case_dir/storefront-next/src/extensions/demo/components"
cat > "$case_dir/storefront-next/src/extensions/demo/components/Widget.tsx" <<'EOF'
import { Button } from '@/components/ui/button';
import { Accordion } from '@/components/ui/accordion';
import { useConfig } from '@salesforce/storefront-next-runtime/config';
export default function Widget() { return null; }
EOF
assert_passes "allowed @/components/ui and storefront-next-runtime imports" "$case_dir"

case_dir="$TMPDIR_ROOT/mention-in-comment-only"
mkdir -p "$case_dir/storefront-next/src/extensions/demo"
cat > "$case_dir/storefront-next/src/extensions/demo/notes.ts" <<'EOF'
// Do not use @salesforce/storefront-ui — prefer @/components/ui
export const ok = true;
EOF
assert_passes "package name mentioned only in a comment" "$case_dir"

# --- Rejecting shapes ---------------------------------------------------

case_dir="$TMPDIR_ROOT/forbidden-named-import"
mkdir -p "$case_dir/storefront-next/src/extensions/demo/components"
cat > "$case_dir/storefront-next/src/extensions/demo/components/Bad.tsx" <<'EOF'
import { Button } from '@salesforce/storefront-ui/components/ui/button';
export default function Bad() { return null; }
EOF
assert_rejects "named import from @salesforce/storefront-ui subpath" "$case_dir" \
  "@salesforce/storefront-ui"

case_dir="$TMPDIR_ROOT/forbidden-require"
mkdir -p "$case_dir/storefront-next/src/extensions/demo"
cat > "$case_dir/storefront-next/src/extensions/demo/legacy.js" <<'EOF'
const ui = require('@salesforce/storefront-ui');
module.exports = ui;
EOF
assert_rejects "require() of @salesforce/storefront-ui" "$case_dir" \
  "@salesforce/storefront-ui"

case_dir="$TMPDIR_ROOT/forbidden-package-root"
mkdir -p "$case_dir/storefront-next/src/extensions/demo"
cat > "$case_dir/storefront-next/src/extensions/demo/index.ts" <<'EOF'
export { Button } from '@salesforce/storefront-ui';
EOF
assert_rejects "re-export from @salesforce/storefront-ui package root" "$case_dir" \
  "@salesforce/storefront-ui"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
