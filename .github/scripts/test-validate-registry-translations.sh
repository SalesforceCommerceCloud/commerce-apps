#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATE="$SCRIPT_DIR/validate-registry-translations.sh"
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
  for spec in "$@"; do
    case "$spec" in
      add:*)
        printf '{}\n' > "$translations_dir/${spec#add:}.json"
        ;;
      remove:*)
        rm "$translations_dir/${spec#remove:}.json"
        ;;
      *)
        echo "Unknown fixture spec: $spec" >&2
        exit 99
        ;;
    esac
  done
  echo "$translations_dir"
}

assert_passes() {
  local desc="$1"
  shift
  local translations_dir
  translations_dir="$(make_translations_dir "$@")"
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
  translations_dir="$(make_translations_dir "$@")"

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

assert_passes "all required default locale files are valid"
assert_passes "additional valid BCP-47 locale is accepted" add:fr-CA
assert_rejects "missing default locale is rejected" \
  "missing required locale file(s): ja.json" remove:ja
assert_rejects "misformatted locale is rejected" \
  "misformatted locale file(s): zh_CN.json" add:zh_CN

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[[ "$FAIL" -eq 0 ]]
