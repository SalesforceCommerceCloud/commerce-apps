#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/root-manifest-utils.sh"

PASS=0
FAIL=0
TMPDIR_ROOT=""
cleanup() { [[ -n "$TMPDIR_ROOT" ]] && rm -rf "$TMPDIR_ROOT"; }
trap cleanup EXIT
TMPDIR_ROOT="$(mktemp -d)"

assert_pass() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc (expected pass)"
    FAIL=$((FAIL + 1))
  fi
}

assert_fail() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then
    echo "  FAIL: $desc (expected fail)"
    FAIL=$((FAIL + 1))
  else
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  fi
}

assert_json_eq() {
  local desc="$1" expected="$2"; shift 2
  local actual
  actual="$("$@" 2>/dev/null)" || { echo "  FAIL: $desc (command failed)"; FAIL=$((FAIL + 1)); return; }
  if [[ "$actual" == "$expected" ]]; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
    echo "    expected: $expected"
    echo "    actual:   $actual"
    FAIL=$((FAIL + 1))
  fi
}

_MC=0
mkmanifest() {
  _MC=$((_MC + 1))
  local f="$TMPDIR_ROOT/manifest_${_MC}.json"
  printf '%s\n' "$1" > "$f"
  printf '%s' "$f"
}

echo "=== root-manifest-utils.sh tests ==="
echo ""

# ---------------------------------------------------------------------------
# validate_semver
# ---------------------------------------------------------------------------
echo "--- validate_semver ---"

assert_pass  "1.0.0"                       validate_semver "1.0.0"
assert_pass  "0.0.0"                       validate_semver "0.0.0"
assert_pass  "100.200.300"                 validate_semver "100.200.300"
assert_pass  "pre-release: 1.0.0-alpha"    validate_semver "1.0.0-alpha"
assert_pass  "pre-release: 1.0.0-rc.1"     validate_semver "1.0.0-rc.1"
assert_pass  "pre-release: 0.4.0-alpha.0"  validate_semver "0.4.0-alpha.0"
assert_pass  "leading zeros: 01.02.03"     validate_semver "01.02.03"

assert_fail  "two segments: 1.0"           validate_semver "1.0"
assert_fail  "four segments: 1.2.3.4"      validate_semver "1.2.3.4"
assert_fail  "single number: 1"            validate_semver "1"
assert_fail  "letters in version: 1.a.0"   validate_semver "1.a.0"
assert_fail  "build metadata: 1.0.0+build" validate_semver "1.0.0+build"
assert_fail  "v-prefix: v1.0.0"            validate_semver "v1.0.0"
assert_fail  "trailing space: '1.0.0 '"    validate_semver "1.0.0 "
assert_fail  "empty pre-release: 1.0.0-"   validate_semver "1.0.0-"
assert_fail  "just text: abc"              validate_semver "abc"

echo ""

# ---------------------------------------------------------------------------
# validate_manifest
# ---------------------------------------------------------------------------
echo "--- validate_manifest ---"

assert_fail  "file does not exist"  validate_manifest "$TMPDIR_ROOT/nonexistent.json"

empty="$TMPDIR_ROOT/empty.json"; : > "$empty"
assert_fail  "empty file"  validate_manifest "$empty"

bad="$TMPDIR_ROOT/bad.json"; printf '{bad}' > "$bad"
assert_fail  "invalid JSON"  validate_manifest "$bad"

assert_pass  "minimal valid manifest"         validate_manifest "$(mkmanifest '{"tax":[]}')"
assert_pass  "entries without zip field"      validate_manifest "$(mkmanifest '{"tax":[{"id":"a"},{"id":"b"}]}')"
assert_pass  "unique zips"                    validate_manifest "$(mkmanifest '{"tax":[{"zip":"a.zip"},{"zip":"b.zip"}]}')"
assert_pass  "non-array values are ignored"   validate_manifest "$(mkmanifest '{"defaultLocale":"en","tax":[{"zip":"a.zip"}]}')"
assert_pass  "mixed entries with/without zip" validate_manifest "$(mkmanifest '{"tax":[{"id":"a"},{"zip":"b.zip"}]}')"

assert_fail  "duplicate zips in same array"   validate_manifest "$(mkmanifest '{"tax":[{"zip":"dup.zip"},{"zip":"dup.zip"}]}')"
assert_fail  "duplicate zips across arrays"   validate_manifest "$(mkmanifest '{"tax":[{"zip":"dup.zip"}],"shipping":[{"zip":"dup.zip"}]}')"

echo ""

# ---------------------------------------------------------------------------
# get_manifest_entry_for_zip
# ---------------------------------------------------------------------------
echo "--- get_manifest_entry_for_zip ---"

m1="$(mkmanifest '{"tax":[{"id":"app1","zip":"app1-v1.0.0.zip","version":"1.0.0"}]}')"
assert_pass     "finds existing zip"   get_manifest_entry_for_zip "app1-v1.0.0.zip" "$m1"
assert_json_eq  "returns correct JSON" '{"id":"app1","zip":"app1-v1.0.0.zip","version":"1.0.0"}' \
  get_manifest_entry_for_zip "app1-v1.0.0.zip" "$m1"

assert_fail  "zip not found"  get_manifest_entry_for_zip "no-such.zip" "$m1"

m_dup="$(mkmanifest '{"tax":[{"zip":"dup.zip","id":"a"}],"shipping":[{"zip":"dup.zip","id":"b"}]}')"
assert_fail  "rejects multiple matches"  get_manifest_entry_for_zip "dup.zip" "$m_dup"

m2="$(mkmanifest '{"tax":[{"zip":"a.zip","id":"a"}],"shipping":[{"zip":"b.zip","id":"b"}]}')"
assert_pass     "finds zip in second array"   get_manifest_entry_for_zip "b.zip" "$m2"
assert_json_eq  "returns entry from second array" '{"zip":"b.zip","id":"b"}' \
  get_manifest_entry_for_zip "b.zip" "$m2"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[[ "$FAIL" -eq 0 ]]
