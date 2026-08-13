#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATE="$SCRIPT_DIR/validate-registry-translations.sh"

PASS=0
FAIL=0
TMPDIR_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_ROOT"' EXIT

assert_passes() {
  local desc="$1"
  shift
  local translations_dir
  translations_dir="$(mktemp -d "$TMPDIR_ROOT/translations.XXXXXX")"
  for locale in "$@"; do
    printf '{}\n' > "$translations_dir/$locale.json"
  done

  local output
  if output="$(bash "$VALIDATE" "$translations_dir" 2>&1)"; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
    echo "    output: $output"
    FAIL=$((FAIL + 1))
  fi
}

assert_rejects() {
  local desc="$1"
  local expect_substr="$2"
  shift 2
  local translations_dir
  translations_dir="$(mktemp -d "$TMPDIR_ROOT/translations.XXXXXX")"
  for locale in "$@"; do
    printf '{}\n' > "$translations_dir/$locale.json"
  done

  local output rc=0
  output="$(bash "$VALIDATE" "$translations_dir" 2>&1)" || rc=$?
  if [[ "$rc" -eq 1 && "$output" == *"$expect_substr"* ]]; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc (expected exit 1 containing '$expect_substr', got exit $rc)"
    echo "    output: $output"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== registry translations validator tests ==="

assert_passes "empty directory is valid"
assert_passes "all supported locale filenames are valid" \
  ar-MA de en-US es fr it ja ko nl pl pt zh-CN zh-TW
assert_passes "additional dash-form locale is valid" en-US fr-CA
assert_rejects "misformatted region separator is rejected" \
  "use BCP-47 dash form" en-US zh_CN

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[[ "$FAIL" -eq 0 ]]
