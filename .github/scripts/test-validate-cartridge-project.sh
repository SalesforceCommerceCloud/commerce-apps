#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATE="$SCRIPT_DIR/validate-cartridge-project.sh"

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

echo "=== cartridge .project validator tests ==="

# --- Passing shapes ---------------------------------------------------

case_dir="$TMPDIR_ROOT/no-cartridges"
mkdir -p "$case_dir/storefront-next"
assert_passes "no cartridges/ directory (UI-only app)" "$case_dir"

case_dir="$TMPDIR_ROOT/empty-project-files"
mkdir -p "$case_dir/cartridges/site_cartridges/int_vendor_app"
mkdir -p "$case_dir/cartridges/bm_cartridges/bm_app"
touch "$case_dir/cartridges/site_cartridges/int_vendor_app/.project"
touch "$case_dir/cartridges/bm_cartridges/bm_app/.project"
assert_passes "empty .project files in both cartridge roots" "$case_dir"

case_dir="$TMPDIR_ROOT/nonempty-project-file"
mkdir -p "$case_dir/cartridges/site_cartridges/int_vendor_app"
cat > "$case_dir/cartridges/site_cartridges/int_vendor_app/.project" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<projectDescription>
  <name>int_vendor_app</name>
</projectDescription>
EOF
assert_passes "non-empty Eclipse .project file is left alone and passes" "$case_dir"

case_dir="$TMPDIR_ROOT/only-site-cartridges"
mkdir -p "$case_dir/cartridges/site_cartridges/int_vendor_app"
touch "$case_dir/cartridges/site_cartridges/int_vendor_app/.project"
assert_passes "backend-only app with only site_cartridges/" "$case_dir"

# --- Rejecting shapes ---------------------------------------------------

case_dir="$TMPDIR_ROOT/missing-site-project"
mkdir -p "$case_dir/cartridges/site_cartridges/int_vendor_app"
assert_rejects "missing .project in site_cartridges root" "$case_dir" \
  "cartridges/site_cartridges/int_vendor_app/.project"

case_dir="$TMPDIR_ROOT/missing-bm-project"
mkdir -p "$case_dir/cartridges/site_cartridges/int_vendor_app"
mkdir -p "$case_dir/cartridges/bm_cartridges/bm_app"
touch "$case_dir/cartridges/site_cartridges/int_vendor_app/.project"
assert_rejects "missing .project in bm_cartridges root" "$case_dir" \
  "cartridges/bm_cartridges/bm_app/.project"

case_dir="$TMPDIR_ROOT/missing-both"
mkdir -p "$case_dir/cartridges/site_cartridges/int_vendor_app"
mkdir -p "$case_dir/cartridges/bm_cartridges/bm_app"
assert_rejects "missing .project in both cartridge roots" "$case_dir" \
  "cartridges/site_cartridges/int_vendor_app/.project"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[[ "$FAIL" -eq 0 ]]
