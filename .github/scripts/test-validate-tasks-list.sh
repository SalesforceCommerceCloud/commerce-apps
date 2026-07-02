#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATE="$SCRIPT_DIR/validate-tasks-list.sh"

PASS=0
FAIL=0
TMPDIR_ROOT=""
cleanup() { [[ -n "$TMPDIR_ROOT" ]] && rm -rf "$TMPDIR_ROOT"; }
trap cleanup EXIT
TMPDIR_ROOT="$(mktemp -d)"

LAST_OUTPUT=""
LAST_RC=0

run_validate_with_content() {
  local content="$1"
  local f="$TMPDIR_ROOT/case_$$_$RANDOM.json"
  printf '%s' "$content" > "$f"
  LAST_OUTPUT="$(bash "$VALIDATE" "$f" 2>&1)" || LAST_RC=$?
  LAST_RC=${LAST_RC:-0}
}

assert_passes() {
  local desc="$1"; local content="$2"
  LAST_RC=0
  run_validate_with_content "$content"
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
  local desc="$1"; local content="$2"; local expect_substr="$3"
  LAST_RC=0
  run_validate_with_content "$content"
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

echo "=== tasksList.json validator tests ==="

# --- Passing shapes --------------------------------------------------------

assert_passes "single valid task" '[
  {"taskKey":"setup_account","name":"Setup","description":"Set up the account.","taskNumber":"1"}
]'

assert_passes "multiple sequential tasks with optional link" '[
  {"taskKey":"setup_account","name":"Setup","description":"Set up account.","taskNumber":"1","link":"https://docs.example.com/setup"},
  {"taskKey":"configure_keys","name":"Keys","description":"Configure API keys.","taskNumber":"2","link":""}
]'

# --- Rejecting shapes ------------------------------------------------------

assert_rejects "invalid JSON is rejected" '{not json' "not valid JSON"

assert_rejects "top-level object is rejected" \
  '{"taskKey":"a","name":"n","description":"d","taskNumber":"1"}' \
  "must be a non-empty JSON array"

assert_rejects "empty array is rejected" '[]' "must be a non-empty JSON array"

assert_rejects "missing taskKey is rejected" \
  '[{"name":"n","description":"d","taskNumber":"1"}]' \
  '"taskKey" is required'

assert_rejects "empty taskKey is rejected" \
  '[{"taskKey":"","name":"n","description":"d","taskNumber":"1"}]' \
  '"taskKey" is required'

assert_rejects "camelCase taskKey is rejected" \
  '[{"taskKey":"setupAccount","name":"n","description":"d","taskNumber":"1"}]' \
  '"taskKey" must match'

assert_rejects "taskKey starting with digit is rejected" \
  '[{"taskKey":"1setup","name":"n","description":"d","taskNumber":"1"}]' \
  '"taskKey" must match'

assert_rejects "missing name is rejected" \
  '[{"taskKey":"a","description":"d","taskNumber":"1"}]' \
  '"name" is required'

assert_rejects "empty description is rejected" \
  '[{"taskKey":"a","name":"n","description":"","taskNumber":"1"}]' \
  '"description" is required'

assert_rejects "missing taskNumber is rejected" \
  '[{"taskKey":"a","name":"n","description":"d"}]' \
  '"taskNumber" is required'

assert_rejects "non-sequential taskNumber is rejected" \
  '[
    {"taskKey":"a","name":"n","description":"d","taskNumber":"1"},
    {"taskKey":"b","name":"n","description":"d","taskNumber":"3"}
  ]' \
  '"taskNumber" must be "2"'

assert_rejects "non-string link is rejected" \
  '[{"taskKey":"a","name":"n","description":"d","taskNumber":"1","link":42}]' \
  '"link" must be a string when present'

assert_rejects "duplicate taskKey is rejected" \
  '[
    {"taskKey":"dup","name":"n","description":"d","taskNumber":"1"},
    {"taskKey":"dup","name":"n","description":"d","taskNumber":"2"}
  ]' \
  "duplicate taskKey values"

assert_rejects "non-object array entry is rejected" \
  '["nope"]' \
  "must be an object"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[[ "$FAIL" -eq 0 ]]
