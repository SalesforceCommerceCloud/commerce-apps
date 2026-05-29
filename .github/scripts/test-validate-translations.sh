#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATE="$SCRIPT_DIR/validate-translations.sh"

PASS=0
FAIL=0
TMPDIR_ROOT=""
cleanup() { [[ -n "$TMPDIR_ROOT" ]] && rm -rf "$TMPDIR_ROOT"; }
trap cleanup EXIT
TMPDIR_ROOT="$(mktemp -d)"

LAST_OUTPUT=""
LAST_RC=0

# Build a CAP root from a small directive language. Each argument is one of:
#   tasks:<filename>:<json>       (writes to app-configuration/translations/<filename>)
#   tasksList:<json>              (writes app-configuration/tasksList.json)
#   adminComponents:<json>        (writes app-configuration/adminComponents.json)
#   no-translations               (skips creating translations dir)
make_cap() {
  local cap; cap="$(mktemp -d "$TMPDIR_ROOT/cap.XXXXXX")"
  local has_translations=true
  for spec in "$@"; do
    case "$spec" in
      no-translations)
        has_translations=false
        ;;
      tasks:*)
        local rest="${spec#tasks:}"
        local filename="${rest%%:*}"
        local content="${rest#*:}"
        mkdir -p "$cap/app-configuration/translations"
        printf '%s' "$content" > "$cap/app-configuration/translations/$filename"
        ;;
      tasksList:*)
        mkdir -p "$cap/app-configuration"
        printf '%s' "${spec#tasksList:}" > "$cap/app-configuration/tasksList.json"
        ;;
      adminComponents:*)
        mkdir -p "$cap/app-configuration"
        printf '%s' "${spec#adminComponents:}" > "$cap/app-configuration/adminComponents.json"
        ;;
      *)
        echo "Unknown spec: $spec" >&2
        exit 99
        ;;
    esac
  done
  if [[ "$has_translations" == "true" && ! -d "$cap/app-configuration/translations" ]]; then
    mkdir -p "$cap/app-configuration/translations"
  fi
  echo "$cap"
}

run_validate() {
  local cap="$1"
  LAST_RC=0
  LAST_OUTPUT="$(bash "$VALIDATE" "$cap" 2>&1)" || LAST_RC=$?
  LAST_RC=${LAST_RC:-0}
}

assert_passes() {
  local desc="$1"; shift
  local cap; cap="$(make_cap "$@")"
  run_validate "$cap"
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
  local desc="$1"; local expect_substr="$2"; shift 2
  local cap; cap="$(make_cap "$@")"
  run_validate "$cap"
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

echo "=== translations/ validator tests ==="

# Common reusable JSON snippets.
EN_BASIC='{"tasks":{"setup_account":{"name":"Setup","description":"Set up the account."}}}'
DE_BASIC='{"tasks":{"setup_account":{"name":"Einrichten","description":"Konto einrichten."}}}'
TASKS_LIST_OK='[{"taskKey":"setup_account","name":"Setup","description":"d","taskNumber":"1"}]'

# --- Passing shapes --------------------------------------------------------

assert_passes "missing translations dir is OK (optional)" no-translations

assert_passes "en-US only" "tasks:en-US.json:$EN_BASIC"

assert_passes "en-US + matching de" \
  "tasks:en-US.json:$EN_BASIC" \
  "tasks:de.json:$DE_BASIC"

assert_passes "tasksList taskKey present in en-US" \
  "tasks:en-US.json:$EN_BASIC" \
  "tasksList:$TASKS_LIST_OK"

assert_passes "adminComponents pair coverage and parity" \
  "tasks:en-US.json:{\"tasks\":{\"setup_account\":{\"name\":\"S\",\"description\":\"d\"}},\"adminComponents\":{\"component_visibility\":{\"attributes\":{\"sfcc.checkout.shippingAddress.after\":{\"label\":\"Show on Checkout\"}}}}}" \
  "tasks:de.json:{\"tasks\":{\"setup_account\":{\"name\":\"S\",\"description\":\"d\"}},\"adminComponents\":{\"component_visibility\":{\"attributes\":{\"sfcc.checkout.shippingAddress.after\":{\"label\":\"Beim Checkout\"}}}}}" \
  "adminComponents:{\"configuration\":[{\"componentKey\":\"component_visibility\",\"type\":\"storefrontComponentVisibility\",\"attributes\":[{\"id\":\"sfcc.checkout.shippingAddress.after\",\"label\":\"Show on Checkout\",\"defaultValue\":true}]}]}"

# --- Rejecting shapes ------------------------------------------------------

assert_rejects "translations dir without en-US.json is rejected" \
  "en-US.json is missing" \
  "tasks:de.json:$DE_BASIC"

assert_rejects "invalid JSON locale is rejected" \
  "not valid JSON" \
  "tasks:en-US.json:{not json"

assert_rejects "missing tasks key is rejected" \
  'missing or non-object "tasks" key' \
  'tasks:en-US.json:{"foo":1}'

assert_rejects "empty name in en-US is rejected" \
  "missing/invalid name or description" \
  'tasks:en-US.json:{"tasks":{"setup_account":{"name":"","description":"d"}}}'

assert_rejects "unsupported locale filename is rejected" \
  "Unsupported locale file" \
  "tasks:en-US.json:$EN_BASIC" \
  "tasks:xx-YY.json:$EN_BASIC"

assert_rejects "tasksList taskKey missing from en-US is rejected" \
  "not present in translations/en-US.json" \
  "tasks:en-US.json:$EN_BASIC" \
  'tasksList:[{"taskKey":"missing_task","name":"M","description":"d","taskNumber":"1"}]'

assert_rejects "non-default locale missing a task key is rejected" \
  "tasks key parity mismatch" \
  'tasks:en-US.json:{"tasks":{"a":{"name":"A","description":"a"},"b":{"name":"B","description":"b"}}}' \
  'tasks:de.json:{"tasks":{"a":{"name":"A","description":"a"}}}'

assert_rejects "non-default locale with extra task key is rejected" \
  "tasks key parity mismatch" \
  'tasks:en-US.json:{"tasks":{"a":{"name":"A","description":"a"}}}' \
  'tasks:de.json:{"tasks":{"a":{"name":"A","description":"a"},"b":{"name":"B","description":"b"}}}'

assert_rejects "locale adminComponents attribute with empty label is rejected" \
  "adminComponents shape invalid" \
  "tasks:en-US.json:{\"tasks\":{\"setup_account\":{\"name\":\"S\",\"description\":\"d\"}},\"adminComponents\":{\"component_visibility\":{\"attributes\":{\"sfcc.checkout.shippingAddress.after\":{\"label\":\"\"}}}}}"

assert_rejects "adminComponents pair missing from en-US is rejected" \
  "not present in translations/en-US.json" \
  "tasks:en-US.json:{\"tasks\":{\"setup_account\":{\"name\":\"S\",\"description\":\"d\"}},\"adminComponents\":{}}" \
  "adminComponents:{\"configuration\":[{\"componentKey\":\"component_visibility\",\"type\":\"storefrontComponentVisibility\",\"attributes\":[{\"id\":\"sfcc.checkout.shippingAddress.after\",\"label\":\"Show\",\"defaultValue\":true}]}]}"

assert_rejects "adminComponents parity mismatch in non-default locale is rejected" \
  "adminComponents key parity mismatch" \
  "tasks:en-US.json:{\"tasks\":{\"setup_account\":{\"name\":\"S\",\"description\":\"d\"}},\"adminComponents\":{\"component_visibility\":{\"attributes\":{\"sfcc.checkout.shippingAddress.after\":{\"label\":\"Show on Checkout\"}}}}}" \
  "tasks:de.json:{\"tasks\":{\"setup_account\":{\"name\":\"S\",\"description\":\"d\"}},\"adminComponents\":{}}" \
  "adminComponents:{\"configuration\":[{\"componentKey\":\"component_visibility\",\"type\":\"storefrontComponentVisibility\",\"attributes\":[{\"id\":\"sfcc.checkout.shippingAddress.after\",\"label\":\"Show on Checkout\",\"defaultValue\":true}]}]}"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[[ "$FAIL" -eq 0 ]]
