#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCAN="$SCRIPT_DIR/security-scan.sh"

PASS=0
FAIL=0
BUGS=0
TMPDIR_ROOT=""
cleanup() { [[ -n "$TMPDIR_ROOT" ]] && rm -rf "$TMPDIR_ROOT"; }
trap cleanup EXIT
TMPDIR_ROOT="$(mktemp -d)"

_DC=0
mkcap() {
  _DC=$((_DC + 1))
  local d="$TMPDIR_ROOT/cap_${_DC}"
  mkdir -p "$d"
  printf '%s' "$d"
}

run_scan() {
  local rc=0
  LAST_OUTPUT="$(bash "$SCAN" "$@" 2>&1)" || rc=$?
  LAST_RC=$rc
}

assert_blocks() {
  local desc="$1"; shift
  run_scan "$@"
  if [[ "$LAST_RC" -eq 1 ]]; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc (expected exit 1, got $LAST_RC)"
    FAIL=$((FAIL + 1))
  fi
}

assert_passes() {
  local desc="$1"; shift
  run_scan "$@"
  if [[ "$LAST_RC" -eq 0 ]]; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc (expected exit 0, got $LAST_RC)"
    FAIL=$((FAIL + 1))
  fi
}

assert_clean() {
  local desc="$1"; shift
  run_scan "$@"
  if [[ "$LAST_RC" -eq 0 ]] && echo "$LAST_OUTPUT" | grep -q "no findings"; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc (expected exit 0 + no findings, got exit $LAST_RC)"
    [[ -n "$LAST_OUTPUT" ]] && echo "    output: $(echo "$LAST_OUTPUT" | tail -3)"
    FAIL=$((FAIL + 1))
  fi
}

assert_warns() {
  local desc="$1" needle="$2"; shift 2
  run_scan "$@"
  if [[ "$LAST_RC" -eq 0 ]] && echo "$LAST_OUTPUT" | grep -qF "$needle"; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc (expected exit 0 + warning containing '$needle', got exit $LAST_RC)"
    FAIL=$((FAIL + 1))
  fi
}

assert_no_warning() {
  local desc="$1" needle="$2"; shift 2
  run_scan "$@"
  if [[ "$LAST_RC" -eq 0 ]] && ! echo "$LAST_OUTPUT" | grep -qF "$needle"; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc (expected no '$needle' warning, but found it)"
    FAIL=$((FAIL + 1))
  fi
}

# Document known bugs — assert current (broken) behavior so tests pass today
# and will fail when the bug is fixed, prompting removal of the workaround.
assert_known_bug() {
  local bug_id="$1" desc="$2" expected_when_fixed="$3"; shift 3
  run_scan "$@"
  local actual_blocks=false
  [[ "$LAST_RC" -eq 1 ]] && actual_blocks=true

  if [[ "$expected_when_fixed" == "block" && "$actual_blocks" == "false" ]]; then
    echo "  BUG:  $desc [$bug_id — should block but doesn't]"
    BUGS=$((BUGS + 1))
  elif [[ "$expected_when_fixed" == "pass" && "$actual_blocks" == "true" ]]; then
    echo "  BUG:  $desc [$bug_id — should pass but blocks]"
    BUGS=$((BUGS + 1))
  else
    echo "  FIXED? $desc [$bug_id — behavior changed, review this test]"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== security-scan.sh tests ==="
echo ""

# ---------------------------------------------------------------------------
# Infrastructure
# ---------------------------------------------------------------------------
echo "--- Infrastructure ---"

run_scan
if [[ "$LAST_RC" -eq 1 ]]; then echo "  PASS: no arguments exits 1"; PASS=$((PASS + 1))
else echo "  FAIL: no arguments exits 1 (got $LAST_RC)"; FAIL=$((FAIL + 1)); fi

run_scan "$TMPDIR_ROOT/nonexistent"
if [[ "$LAST_RC" -eq 1 ]]; then echo "  PASS: nonexistent dir exits 1"; PASS=$((PASS + 1))
else echo "  FAIL: nonexistent dir exits 1 (got $LAST_RC)"; FAIL=$((FAIL + 1)); fi

cap="$(mkcap)"
assert_clean "empty directory passes clean" "$cap"

echo ""

# ---------------------------------------------------------------------------
# S1: eval / new Function
# ---------------------------------------------------------------------------
echo "--- S1: eval / new Function ---"

cap="$(mkcap)"; printf 'var x = eval(input);\n' > "$cap/app.js"
assert_blocks "eval() in code" "$cap"

cap="$(mkcap)"; printf 'var fn = new Function("return x");\n' > "$cap/app.js"
assert_blocks "new Function() in code" "$cap"

# BUG: grep -n prefixes "1://" so grep -v '^\s*//' never matches the comment.
cap="$(mkcap)"; printf '// eval(input);\n' > "$cap/app.js"
assert_known_bug "S1-COMMENT" "eval in line comment should be ignored" "pass" "$cap"

cap="$(mkcap)"; printf '// new Function("return x");\n' > "$cap/app.js"
assert_known_bug "S1-COMMENT" "new Function in comment should be ignored" "pass" "$cap"

echo ""

# ---------------------------------------------------------------------------
# S2: Dynamic require
# ---------------------------------------------------------------------------
echo "--- S2: Dynamic require ---"

cap="$(mkcap)"; printf "var m = require(path + '/lib');\n" > "$cap/app.js"
assert_blocks "dynamic require with concatenation" "$cap"

cap="$(mkcap)"; printf "var m = require('lodash');\n" > "$cap/app.js"
assert_passes "static require is safe" "$cap"

echo ""

# ---------------------------------------------------------------------------
# S3: innerHTML
# ---------------------------------------------------------------------------
echo "--- S3: innerHTML ---"

cap="$(mkcap)"; printf 'el.innerHTML = userInput;\n' > "$cap/app.js"
assert_blocks "innerHTML assignment" "$cap"

cap="$(mkcap)"; printf 'var x = el.innerHTML;\n' > "$cap/app.js"
assert_passes "innerHTML read is safe" "$cap"

echo ""

# ---------------------------------------------------------------------------
# S4: Hardcoded secrets
# ---------------------------------------------------------------------------
echo "--- S4: Hardcoded secrets ---"

cap="$(mkcap)"; printf 'var key = "AKIAIOSFODNN7EXAMPLE";\n' > "$cap/app.js"
assert_blocks "AWS access key" "$cap"

cap="$(mkcap)"; printf 'var tok = "ghp_aBcDeFgHiJkLmNoPqRsTuVwXyZ0123456789";\n' > "$cap/app.js"
assert_blocks "GitHub PAT" "$cap"

cap="$(mkcap)"; printf 'var t = "Bearer eyJhbGciOiJIUzI1NiJ9.xxxxx";\n' > "$cap/app.js"
assert_blocks "Bearer token" "$cap"

cap="$(mkcap)"; printf 'var s = "xoxb-1234567890-abcdef";\n' > "$cap/app.js"
assert_blocks "Slack token" "$cap"

cap="$(mkcap)"; printf 'var x = "sk_live_abc123defgh";\n' > "$cap/app.js"
assert_blocks "Stripe-style live key" "$cap"

# BUG: grep parses "-----BEGIN" as --BEGIN flag; pattern never matches.
cap="$(mkcap)"; printf 'var k = "-----BEGIN RSA PRIVATE KEY-----";\n' > "$cap/app.js"
assert_known_bug "S4-PRIVKEY" "RSA private key header should block" "block" "$cap"

cap="$(mkcap)"; printf 'var k = "-----BEGIN PRIVATE KEY-----";\n' > "$cap/app.js"
assert_known_bug "S4-PRIVKEY" "generic private key header should block" "block" "$cap"

echo ""

# ---------------------------------------------------------------------------
# S5: Hardcoded secrets in XML
# ---------------------------------------------------------------------------
echo "--- S5: XML credentials ---"

cap="$(mkcap)"; printf '<cred><password>SuperSecretPasswordThatIsLong</password></cred>\n' > "$cap/svc.xml"
assert_blocks "long password in XML" "$cap"

cap="$(mkcap)"; printf '<cred><password>short</password></cred>\n' > "$cap/svc.xml"
assert_passes "short password in XML is safe (under 20 chars)" "$cap"

cap="$(mkcap)"; printf '<cred><password>PLACEHOLDER_CHANGEME_VALUE</password></cred>\n' > "$cap/svc.xml"
assert_passes "CHANGEME placeholder in XML is safe" "$cap"

echo ""

# ---------------------------------------------------------------------------
# S6: Math.random
# ---------------------------------------------------------------------------
echo "--- S6: Math.random ---"

cap="$(mkcap)"; printf 'var r = Math.random();\n' > "$cap/app.js"
assert_warns "Math.random() warns" "Math.random()" "$cap"

echo ""

# ---------------------------------------------------------------------------
# S7: Inline Authorization header
# ---------------------------------------------------------------------------
echo "--- S7: Inline Authorization ---"

cap="$(mkcap)"; printf "req.setRequestHeader('Authorization', token);\n" > "$cap/app.js"
assert_warns "setRequestHeader Authorization warns" "Inline Authorization" "$cap"

echo ""

# ---------------------------------------------------------------------------
# P1: console.log
# ---------------------------------------------------------------------------
echo "--- P1: console.log ---"

cap="$(mkcap)"; printf 'console.log("debug");\n' > "$cap/cart.js"
assert_warns "console.log warns" "console.log" "$cap"

echo ""

# ---------------------------------------------------------------------------
# P2: HTTPClient without timeout
# ---------------------------------------------------------------------------
echo "--- P2: HTTPClient timeout ---"

cap="$(mkcap)"; printf 'var c = new HTTPClient();\nc.open("GET", url);\n' > "$cap/svc.js"
assert_warns "HTTPClient without timeout warns" "HTTPClient used without explicit timeout" "$cap"

# BUG: grep -qE 'setTimeout\|...' uses \| which is literal in ERE mode, not alternation.
# setTimeout is never recognized, so HTTPClient with setTimeout still warns falsely.
cap="$(mkcap)"; printf 'var c = new HTTPClient();\nc.setTimeout(5000);\n' > "$cap/svc.js"
run_scan "$cap"
if [[ "$LAST_RC" -eq 0 ]] && echo "$LAST_OUTPUT" | grep -qF "HTTPClient used without explicit timeout"; then
  echo "  BUG:  HTTPClient with setTimeout still warns [P2-TIMEOUT — \\| is literal in ERE]"
  BUGS=$((BUGS + 1))
else
  echo "  FIXED? HTTPClient with setTimeout no longer warns [P2-TIMEOUT — review this test]"
  FAIL=$((FAIL + 1))
fi

echo ""

# ---------------------------------------------------------------------------
# P3: Service profile timeout
# ---------------------------------------------------------------------------
echo "--- P3: Service profile timeout ---"

cap="$(mkcap)"; mkdir -p "$cap/impex/install"
printf '<service-profile service-id="MySvc"/>\n' > "$cap/impex/install/profiles.xml"
assert_warns "service profile without timeout-millis warns" "Service profile missing" "$cap"

cap="$(mkcap)"; mkdir -p "$cap/impex/install"
printf '<service-profile service-id="MySvc"><timeout-millis>5000</timeout-millis></service-profile>\n' > "$cap/impex/install/profiles.xml"
assert_no_warning "service profile with timeout — no timeout warning" "Service profile missing" "$cap"

cap="$(mkcap)"; mkdir -p "$cap/impex/uninstall"
printf '<service-profile service-id="MySvc"/>\n' > "$cap/impex/uninstall/profiles.xml"
assert_no_warning "service profile in uninstall dir is skipped" "Service profile missing" "$cap"

echo ""

# ---------------------------------------------------------------------------
# Q1: Hook script existence
# ---------------------------------------------------------------------------
echo "--- Q1: Hook script existence ---"

cap="$(mkcap)"
printf '{"hooks":[{"name":"sfcc.app.tax.calculate","script":"./hooks/tax.js"}]}\n' > "$cap/hooks.json"
assert_blocks "missing hook script blocks" "$cap"

cap="$(mkcap)"; mkdir -p "$cap/hooks"
printf '{"hooks":[{"name":"sfcc.app.tax.calculate","script":"./hooks/tax.js"}]}\n' > "$cap/hooks.json"
printf 'exports.calculate = function() { try { run(); } catch(e) {} };\n' > "$cap/hooks/tax.js"
assert_passes "existing hook script with export + try/catch passes" "$cap"

echo ""

# ---------------------------------------------------------------------------
# Q2: Hook function exported
# ---------------------------------------------------------------------------
echo "--- Q2: Hook function export ---"

cap="$(mkcap)"; mkdir -p "$cap/hooks"
printf '{"hooks":[{"name":"sfcc.app.tax.calculate","script":"./hooks/tax.js"}]}\n' > "$cap/hooks.json"
printf 'function calculate() { try { run(); } catch(e) {} }\n' > "$cap/hooks/tax.js"
assert_warns "unexported hook function warns" "expects export 'calculate'" "$cap"

cap="$(mkcap)"; mkdir -p "$cap/hooks"
printf '{"hooks":[{"name":"sfcc.app.tax.calculate","script":"./hooks/tax.js"}]}\n' > "$cap/hooks.json"
printf 'exports.calculate = function() { try { run(); } catch(e) {} };\n' > "$cap/hooks/tax.js"
assert_no_warning "exported hook function — no export warning" "expects export" "$cap"

echo ""

# ---------------------------------------------------------------------------
# Q3: Error handling in hooks
# ---------------------------------------------------------------------------
echo "--- Q3: Hook error handling ---"

cap="$(mkcap)"; mkdir -p "$cap/hooks"
printf '{"hooks":[{"name":"sfcc.app.tax.calculate","script":"./hooks/tax.js"}]}\n' > "$cap/hooks.json"
printf 'exports.calculate = function() { return 1; };\n' > "$cap/hooks/tax.js"
assert_warns "hook without try/catch warns" "no try/catch" "$cap"

cap="$(mkcap)"; mkdir -p "$cap/hooks"
printf '{"hooks":[{"name":"sfcc.app.tax.calculate","script":"./hooks/tax.js"}]}\n' > "$cap/hooks.json"
printf 'exports.calculate = function() { try { run(); } catch(e) {} };\n' > "$cap/hooks/tax.js"
assert_no_warning "hook with try/catch — no error handling warning" "no try/catch" "$cap"

echo ""

# ---------------------------------------------------------------------------
# Q4: Install/uninstall service symmetry
# ---------------------------------------------------------------------------
echo "--- Q4: Service install/uninstall symmetry ---"

cap="$(mkcap)"; mkdir -p "$cap/impex/install"
printf '<services><service-credential service-id="svc1"/></services>\n' > "$cap/impex/install/services.xml"
assert_blocks "install without uninstall blocks" "$cap"

cap="$(mkcap)"; mkdir -p "$cap/impex/install" "$cap/impex/uninstall"
printf '<services><service-credential service-id="svc1"/></services>\n' > "$cap/impex/install/services.xml"
printf '<services><service-credential service-id="svc1"/></services>\n' > "$cap/impex/uninstall/services.xml"
assert_blocks "uninstall without mode=delete blocks" "$cap"

cap="$(mkcap)"; mkdir -p "$cap/impex/install" "$cap/impex/uninstall"
printf '<services><service-credential service-id="svc1"/></services>\n' > "$cap/impex/install/services.xml"
printf '<services mode="delete"><service-credential service-id="svc1" mode="delete"/></services>\n' > "$cap/impex/uninstall/services.xml"
assert_passes "matching install/uninstall with mode=delete passes" "$cap"

echo ""

# ---------------------------------------------------------------------------
# Q5: SITEID placeholder
# ---------------------------------------------------------------------------
echo "--- Q5: SITEID placeholder ---"

cap="$(mkcap)"; printf '<site site-id="MySite"><prefs/></site>\n' > "$cap/prefs.xml"
assert_warns "hardcoded site-id warns" "Hardcoded site-id" "$cap"

cap="$(mkcap)"; printf '<site site-id="SITEID"><prefs/></site>\n' > "$cap/prefs.xml"
assert_no_warning "SITEID placeholder — no site-id warning" "Hardcoded site-id" "$cap"

echo ""

# ---------------------------------------------------------------------------
# Q6: Absolute paths
# ---------------------------------------------------------------------------
echo "--- Q6: Absolute paths ---"

cap="$(mkcap)"; printf "var p = '/tmp/data';\n" > "$cap/app.js"
assert_warns "absolute /tmp/ path warns" "Absolute path" "$cap"

cap="$(mkcap)"; printf "var p = './data';\n" > "$cap/app.js"
assert_no_warning "relative path — no absolute path warning" "Absolute path" "$cap"

echo ""

# ---------------------------------------------------------------------------
# Combination: warnings don't block
# ---------------------------------------------------------------------------
echo "--- Combination ---"

cap="$(mkcap)"
printf 'console.log("debug");\nvar r = Math.random();\n' > "$cap/app.js"
run_scan "$cap"
if [[ "$LAST_RC" -eq 0 ]]; then echo "  PASS: multiple warnings still exit 0"; PASS=$((PASS + 1))
else echo "  FAIL: multiple warnings still exit 0 (got $LAST_RC)"; FAIL=$((FAIL + 1)); fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed, $BUGS known bugs ==="
[[ "$FAIL" -eq 0 ]]
