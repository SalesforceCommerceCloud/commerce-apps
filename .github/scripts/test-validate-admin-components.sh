#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATE="$SCRIPT_DIR/validate-admin-components.sh"

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

echo "=== adminComponents.json validator tests ==="

# --- Passing shapes --------------------------------------------------------

assert_passes "canonical full shape (connectionDetails + storefrontComponentVisibility)" '{
  "connectionDetails": [
    {
      "type": "healthCheck",
      "header": "Connection Status",
      "description": "Live health status of the API connection."
    }
  ],
  "configuration": [
    {
      "type": "storefrontComponentVisibility",
      "header": "Component Visibility",
      "description": "Control where the component appears on the storefront.",
      "attributes": [
        { "id": "sfcc.checkout.shippingAddress.after", "label": "Show on Checkout", "defaultValue": true },
        { "id": "sfcc.myAccount.address.validation",   "label": "Show on My Account", "defaultValue": true }
      ]
    }
  ]
}'

assert_passes "empty object (both sections optional)" '{}'

assert_passes "only connectionDetails present" '{
  "connectionDetails": [
    { "type": "healthCheck", "header": "Status", "description": "ok" }
  ]
}'

assert_passes "only configuration present, non-SCV type" '{
  "configuration": [{ "type": "someFutureType" }]
}'

assert_passes "configuration with valid storefrontComponentVisibility" '{
  "configuration": [{
    "type": "storefrontComponentVisibility",
    "attributes": [
      { "id": "sfcc.checkout.shippingAddress.after", "label": "Show on Checkout", "defaultValue": true }
    ]
  }]
}'

assert_passes "SCV under connectionDetails is not deep-validated" '{
  "connectionDetails": [{ "type": "storefrontComponentVisibility" }]
}'

assert_passes "empty arrays are allowed" '{
  "connectionDetails": [],
  "configuration": []
}'

# --- Rejecting shapes ------------------------------------------------------

assert_rejects "top-level array (legacy shape) is rejected" \
  '[{"type":"storefrontComponentVisibility","attributes":[]}]' \
  "must be a JSON object"

assert_rejects "top-level string is rejected" \
  '"hello"' \
  "must be a JSON object"

assert_rejects "invalid JSON is rejected" \
  '{not json' \
  "not valid JSON"

assert_rejects "connectionDetails as string is rejected" \
  '{"connectionDetails":"foo"}' \
  '"connectionDetails" must be an array'

assert_rejects "configuration as object is rejected" \
  '{"configuration":{"type":"x"}}' \
  '"configuration" must be an array'

assert_rejects "entry without type is rejected" \
  '{"connectionDetails":[{}]}' \
  'connectionDetails[0]: "type" is required'

assert_rejects "entry with empty type is rejected" \
  '{"configuration":[{"type":""}]}' \
  'configuration[0]: "type" is required'

assert_rejects "entry that is not an object is rejected" \
  '{"configuration":["nope"]}' \
  'configuration[0]: must be an object'

assert_rejects "SCV without attributes is rejected" \
  '{"configuration":[{"type":"storefrontComponentVisibility"}]}' \
  'requires non-empty "attributes" array'

assert_rejects "SCV with empty attributes is rejected" \
  '{"configuration":[{"type":"storefrontComponentVisibility","attributes":[]}]}' \
  'requires non-empty "attributes" array'

assert_rejects "SCV attribute missing id is rejected" \
  '{"configuration":[{"type":"storefrontComponentVisibility","attributes":[{"label":"x","defaultValue":true}]}]}' \
  'attributes[0]: "id" is required'

assert_rejects "SCV attribute with empty label is rejected" \
  '{"configuration":[{"type":"storefrontComponentVisibility","attributes":[{"id":"a","label":"","defaultValue":true}]}]}' \
  'attributes[0]: "label" is required'

assert_rejects "SCV attribute with non-boolean defaultValue is rejected" \
  '{"configuration":[{"type":"storefrontComponentVisibility","attributes":[{"id":"a","label":"b","defaultValue":"true"}]}]}' \
  'attributes[0]: "defaultValue" is required and must be a boolean'

assert_rejects "SCV attribute missing defaultValue is rejected" \
  '{"configuration":[{"type":"storefrontComponentVisibility","attributes":[{"id":"a","label":"b"}]}]}' \
  'attributes[0]: "defaultValue" is required'

assert_rejects "error indices reflect real positions" \
  '{"configuration":[{"type":"healthCheck"},{"type":"storefrontComponentVisibility","attributes":[{"id":"a","label":"b","defaultValue":true},{"id":"","label":"x","defaultValue":true}]}]}' \
  'configuration[1].attributes[1]: "id" is required'

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[[ "$FAIL" -eq 0 ]]
