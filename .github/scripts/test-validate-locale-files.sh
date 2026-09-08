#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATE="$SCRIPT_DIR/validate-locale-files.sh"
REQUIRED_LOCALES="$SCRIPT_DIR/../config/required-bm-locales.txt"

PASS=0
FAIL=0
TMPDIR_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_ROOT"' EXIT

make_translations_dir() {
  local translations_dir
  translations_dir="$(mktemp -d "$TMPDIR_ROOT/translations.XXXXXX")"
  while IFS= read -r locale || [[ -n "$locale" ]]; do
    locale="${locale%$'\r'}"
    [[ -z "$locale" ]] && continue
    printf '{}\n' > "$translations_dir/$locale.json"
  done < "$REQUIRED_LOCALES"
  echo "$translations_dir"
}

assert_passes() {
  local desc="$1"
  local translations_dir="$2"
  local output
  if output="$(bash "$VALIDATE" "$translations_dir" "Test translations" 2>&1)"; then
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
  local translations_dir="$3"
  local output rc=0
  output="$(bash "$VALIDATE" "$translations_dir" "Test translations" 2>&1)" || rc=$?
  if [[ "$rc" -eq 1 && "$output" == *"$expect_substr"* ]]; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc (expected exit 1 containing '$expect_substr', got exit $rc)"
    echo "    output: $output"
    FAIL=$((FAIL + 1))
  fi
}

assert_usage_error() {
  local desc="$1"
  local expect_substr="$2"
  shift 2
  local output rc=0
  output="$("$@" 2>&1)" || rc=$?
  if [[ "$rc" -eq 2 && "$output" == *"$expect_substr"* ]]; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc (expected exit 2 containing '$expect_substr', got exit $rc)"
    echo "    output: $output"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== locale files validator tests ==="

translations_dir="$(make_translations_dir)"
assert_passes "all required locales are present" "$translations_dir"

translations_dir="$(make_translations_dir)"
rm "$translations_dir/fr.json"
assert_rejects "missing required locale is rejected" \
  "missing required locale file(s): fr.json" "$translations_dir"

translations_dir="$(make_translations_dir)"
printf '{}\n' > "$translations_dir/fr-CA.json"
assert_passes "additional valid BCP-47 locale is accepted" "$translations_dir"

translations_dir="$(make_translations_dir)"
printf '{}\n' > "$translations_dir/zh_CN.json"
assert_rejects "misformatted locale filename is rejected" \
  "misformatted locale file(s): zh_CN.json" "$translations_dir"

assert_usage_error "missing directory is a usage error" \
  "not found" bash "$VALIDATE" "$TMPDIR_ROOT/missing"

translations_dir="$(make_translations_dir)"
assert_usage_error "missing required locale configuration is a usage error" \
  "configuration not found" env REQUIRED_BM_LOCALES_FILE="$TMPDIR_ROOT/missing-locales.txt" \
  bash "$VALIDATE" "$translations_dir"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[[ "$FAIL" -eq 0 ]]
