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

mkcap() {
  local d
  d="$(mktemp -d "$TMPDIR_ROOT/cap_XXXXXX")"
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

cap="$(mkcap)"; printf '// eval(input);\n' > "$cap/app.js"
assert_passes "eval in line comment is ignored" "$cap"

cap="$(mkcap)"; printf '// new Function("return x");\n' > "$cap/app.js"
assert_passes "new Function in line comment is ignored" "$cap"

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

cap="$(mkcap)"; printf 'var k = "-----BEGIN RSA PRIVATE KEY-----";\n' > "$cap/app.js"
assert_blocks "RSA private key header blocks" "$cap"

cap="$(mkcap)"; printf 'var k = "-----BEGIN PRIVATE KEY-----";\n' > "$cap/app.js"
assert_blocks "generic private key header blocks" "$cap"

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
# S7: Inline Authorization header (BLOCK)
# ---------------------------------------------------------------------------
echo "--- S7: Inline Authorization ---"

cap="$(mkcap)"; printf "req.setRequestHeader('Authorization', token);\n" > "$cap/app.js"
assert_blocks "setRequestHeader Authorization blocks" "$cap"

echo ""

# ---------------------------------------------------------------------------
# S8: Additional DOM sinks (BLOCK)
# ---------------------------------------------------------------------------
echo "--- S8: Additional DOM sinks ---"

cap="$(mkcap)"; printf 'el.outerHTML = data;\n' > "$cap/app.js"
assert_blocks "outerHTML assignment detected" "$cap"

cap="$(mkcap)"; printf 'var x = el.outerHTML;\n' > "$cap/app.js"
assert_passes "outerHTML read is safe (no assignment)" "$cap"

cap="$(mkcap)"; printf "document['write'](html);\n" > "$cap/app.js"
assert_blocks "document write call detected" "$cap"

cap="$(mkcap)"; printf "document['writeln'](html);\n" > "$cap/app.js"
assert_blocks "document writeln call detected" "$cap"

cap="$(mkcap)"; printf 'el.insertAdjacentHTML("beforeend", data);\n' > "$cap/app.js"
assert_blocks "insertAdjacentHTML detected" "$cap"

cap="$(mkcap)"; printf '// el.outerHTML = data;\n' > "$cap/app.js"
assert_passes "outerHTML in comment is ignored" "$cap"

cap="$(mkcap)"; printf "// document['write'](html);\n" > "$cap/app.js"
assert_passes "document write in comment is ignored" "$cap"

echo ""

# ---------------------------------------------------------------------------
# S9: ISML template injection (BLOCK)
# ---------------------------------------------------------------------------
echo "--- S9: ISML template injection ---"

cap="$(mkcap)"; printf '<isprint value="${pdict.data}" encoding="off"/>\n' > "$cap/template.isml"
assert_blocks "encoding off detected" "$cap"

cap="$(mkcap)"; printf '<isprint value="${pdict.data}" encoding="htmlcontent"/>\n' > "$cap/template.isml"
assert_passes "proper encoding is safe" "$cap"

cap="$(mkcap)"; printf '<isprint value="${pdict.data}"/>\n' > "$cap/template.isml"
assert_passes "default encoding is safe" "$cap"

cap="$(mkcap)"
assert_passes "no ISML files in package — handled gracefully" "$cap"

echo ""

# ---------------------------------------------------------------------------
# S10: Secret files in package (BLOCK)
# ---------------------------------------------------------------------------
echo "--- S10: Secret files ---"

cap="$(mkcap)"; touch "$cap/.env"
assert_blocks "dotenv file detected" "$cap"

cap="$(mkcap)"; touch "$cap/production.env"
assert_blocks "named .env file detected" "$cap"

cap="$(mkcap)"; touch "$cap/server.key"
assert_blocks "key file detected" "$cap"

cap="$(mkcap)"; touch "$cap/cert.pem"
assert_blocks "PEM file detected" "$cap"

cap="$(mkcap)"; touch "$cap/keystore.p12"
assert_blocks "P12 file detected" "$cap"

cap="$(mkcap)"; touch "$cap/store.pfx"
assert_blocks "PFX file detected" "$cap"

cap="$(mkcap)"; touch "$cap/keys.jks"
assert_blocks "JKS file detected" "$cap"

cap="$(mkcap)"; printf 'readme\n' > "$cap/readme.md"; printf 'app()\n' > "$cap/app.js"
assert_passes "normal files don't trigger" "$cap"

cap="$(mkcap)"; printf '{}' > "$cap/data.json"
assert_passes "non-secret extensions safe" "$cap"

echo ""

# ---------------------------------------------------------------------------
# S11: Raw HTTP outside service framework (BLOCK)
# ---------------------------------------------------------------------------
echo "--- S11: Direct HTTPClient ---"

cap="$(mkcap)"; printf 'var c = new HTTPClient();\n' > "$cap/svc.js"
assert_blocks "direct HTTPClient usage" "$cap"

cap="$(mkcap)"; printf '// var c = new HTTPClient();\n' > "$cap/svc.js"
assert_passes "HTTPClient in line comment is ignored" "$cap"

cap="$(mkcap)"; printf '/* HTTPClient docs */\n' > "$cap/svc.js"
assert_passes "HTTPClient in block comment is ignored" "$cap"

cap="$(mkcap)"; printf 'LocalServiceRegistry.createService("my.svc", {});\n' > "$cap/svc.js"
assert_passes "service framework usage is safe" "$cap"

cap="$(mkcap)"; printf 'var c = new HTTPClient();\n' > "$cap/svc.ts"
assert_blocks "also detects in TypeScript" "$cap"

echo ""

# ---------------------------------------------------------------------------
# S12: Sensitive data in logs (WARN)
# ---------------------------------------------------------------------------
echo "--- S12: Sensitive data in logs ---"

cap="$(mkcap)"; printf 'Logger.info("password=" + password);\n' > "$cap/app.js"
assert_warns "PII field name in Logger" "Possible PII" "$cap"

cap="$(mkcap)"; printf 'Logger.error("creditCard: " + card);\n' > "$cap/app.js"
assert_warns "creditCard field in Logger" "Possible PII" "$cap"

cap="$(mkcap)"; printf 'log.debug("ssn=" + val);\n' > "$cap/app.js"
assert_warns "ssn via log.debug" "Possible PII" "$cap"

cap="$(mkcap)"; printf 'Logger.info("Request processed successfully");\n' > "$cap/app.js"
assert_no_warning "no PII field names" "Possible PII" "$cap"

cap="$(mkcap)"; printf 'Logger.info("password policy updated");\n' > "$cap/app.js"
assert_warns "false positive acceptable — WARN only" "Possible PII" "$cap"

cap="$(mkcap)"; printf '// Logger.info("password=" + pw);\n' > "$cap/app.js"
assert_no_warning "commented out is ignored" "Possible PII" "$cap"

echo ""

# ---------------------------------------------------------------------------
# S13: Blocking/sleep in hooks (BLOCK)
# ---------------------------------------------------------------------------
echo "--- S13: Blocking/sleep in hooks ---"

cap="$(mkcap)"; mkdir -p "$cap/hooks"
printf '{"hooks":[{"name":"sfcc.app.tax.calculate","script":"./hooks/tax.js"}]}\n' > "$cap/hooks.json"
printf 'exports.calculate = function() { try { setTimeout(fn, 5000); } catch(e) {} };\n' > "$cap/hooks/tax.js"
assert_blocks "setTimeout in hook" "$cap"

cap="$(mkcap)"; mkdir -p "$cap/hooks"
printf '{"hooks":[{"name":"sfcc.app.tax.calculate","script":"./hooks/tax.js"}]}\n' > "$cap/hooks.json"
printf 'exports.calculate = function() { try { setInterval(poll, 1000); } catch(e) {} };\n' > "$cap/hooks/tax.js"
assert_blocks "setInterval in hook" "$cap"

cap="$(mkcap)"; printf 'setTimeout(fn, 100);\n' > "$cap/util.js"
assert_passes "setTimeout outside hooks is not checked" "$cap"

cap="$(mkcap)"; mkdir -p "$cap/hooks"
printf '{"hooks":[{"name":"sfcc.app.tax.calculate","script":"./hooks/tax.js"}]}\n' > "$cap/hooks.json"
printf 'exports.calculate = function() { try { return compute(); } catch(e) {} };\n' > "$cap/hooks/tax.js"
assert_passes "clean hook passes" "$cap"

cap="$(mkcap)"; printf 'setTimeout(fn, 100);\n' > "$cap/app.js"
assert_passes "HOOKS_FILES empty, S13 skipped" "$cap"

echo ""

# ---------------------------------------------------------------------------
# S14: Unbounded loops (BLOCK)
# ---------------------------------------------------------------------------
echo "--- S14: Unbounded loops ---"

cap="$(mkcap)"; printf 'while(true) { doWork(); }\n' > "$cap/app.js"
assert_blocks "while-true without break" "$cap"

cap="$(mkcap)"; printf 'for(;;) { process(); }\n' > "$cap/app.js"
assert_blocks "for-ever without break" "$cap"

cap="$(mkcap)"; printf 'while(true) { if (done) break; doWork(); }\n' > "$cap/app.js"
assert_passes "while-true with break within 20 lines" "$cap"

cap="$(mkcap)"; printf 'for(;;) { if (x) return result; work(); }\n' > "$cap/app.js"
assert_passes "for-ever with return within 20 lines" "$cap"

cap="$(mkcap)"; printf '// while(true) { }\n' > "$cap/app.js"
assert_passes "loop in line comment is ignored" "$cap"

cap="$(mkcap)"; printf 'while (condition) { work(); }\n' > "$cap/app.js"
assert_passes "bounded loop is not flagged" "$cap"

echo ""

# ---------------------------------------------------------------------------
# S15: Missing rate limiting / circuit breaker (BLOCK)
# ---------------------------------------------------------------------------
echo "--- S15: Rate limiting / circuit breaker ---"

# Test 1: tax domain missing rate limiting
cap="$(mkcap)"; mkdir -p "$cap/impex/install"
printf '{"domain":"tax"}\n' > "$cap/commerce-app.json"
printf '<service-profile service-id="MySvc"><timeout-millis>5000</timeout-millis></service-profile>\n' > "$cap/impex/install/services.xml"
mkdir -p "$cap/impex/uninstall"
printf '<services mode="delete"><service-credential service-id="MySvc" mode="delete"/></services>\n' > "$cap/impex/uninstall/services.xml"
run_scan "$cap"
if [[ "$LAST_RC" -eq 1 ]] && echo "$LAST_OUTPUT" | grep -qF "tax"; then
  echo "  PASS: tax app missing rate limiting — blocks with tax ideal values"
  PASS=$((PASS + 1))
else
  echo "  FAIL: tax app missing rate limiting (expected block + tax in output, got exit $LAST_RC)"
  FAIL=$((FAIL + 1))
fi

# Test 2: payment domain missing circuit breaker
cap="$(mkcap)"; mkdir -p "$cap/impex/install"
printf '{"domain":"payment"}\n' > "$cap/commerce-app.json"
printf '<service-profile service-id="MySvc"><timeout-millis>10000</timeout-millis><rate-limit-enabled>true</rate-limit-enabled></service-profile>\n' > "$cap/impex/install/services.xml"
mkdir -p "$cap/impex/uninstall"
printf '<services mode="delete"><service-credential service-id="MySvc" mode="delete"/></services>\n' > "$cap/impex/uninstall/services.xml"
run_scan "$cap"
if [[ "$LAST_RC" -eq 1 ]] && echo "$LAST_OUTPUT" | grep -qF "payment"; then
  echo "  PASS: payment app missing circuit breaker — blocks with payment ideal values"
  PASS=$((PASS + 1))
else
  echo "  FAIL: payment app missing circuit breaker (expected block + payment in output, got exit $LAST_RC)"
  FAIL=$((FAIL + 1))
fi

# Test 3: shipping domain missing both
cap="$(mkcap)"; mkdir -p "$cap/impex/install"
printf '{"domain":"shipping"}\n' > "$cap/commerce-app.json"
printf '<service-profile service-id="MySvc"><timeout-millis>5000</timeout-millis></service-profile>\n' > "$cap/impex/install/services.xml"
mkdir -p "$cap/impex/uninstall"
printf '<services mode="delete"><service-credential service-id="MySvc" mode="delete"/></services>\n' > "$cap/impex/uninstall/services.xml"
run_scan "$cap"
if [[ "$LAST_RC" -eq 1 ]] && echo "$LAST_OUTPUT" | grep -qF "shipping"; then
  echo "  PASS: shipping app missing both — blocks with shipping ideal values"
  PASS=$((PASS + 1))
else
  echo "  FAIL: shipping app missing both (expected block + shipping in output, got exit $LAST_RC)"
  FAIL=$((FAIL + 1))
fi

# Test 4: non-provider domain (loyalty) missing both
cap="$(mkcap)"; mkdir -p "$cap/impex/install"
printf '{"domain":"loyalty"}\n' > "$cap/commerce-app.json"
printf '<service-profile service-id="MySvc"><timeout-millis>10000</timeout-millis></service-profile>\n' > "$cap/impex/install/services.xml"
mkdir -p "$cap/impex/uninstall"
printf '<services mode="delete"><service-credential service-id="MySvc" mode="delete"/></services>\n' > "$cap/impex/uninstall/services.xml"
run_scan "$cap"
if [[ "$LAST_RC" -eq 1 ]] && echo "$LAST_OUTPUT" | grep -qF "loyalty"; then
  echo "  PASS: loyalty app missing both — blocks with default ideal values"
  PASS=$((PASS + 1))
else
  echo "  FAIL: loyalty app missing both (expected block + loyalty in output, got exit $LAST_RC)"
  FAIL=$((FAIL + 1))
fi

# Test 5: fully configured profile passes
cap="$(mkcap)"; mkdir -p "$cap/impex/install"
printf '{"domain":"tax"}\n' > "$cap/commerce-app.json"
printf '<service-profile service-id="MySvc"><timeout-millis>5000</timeout-millis><rate-limit-enabled>true</rate-limit-enabled><circuit-breaker-enabled>true</circuit-breaker-enabled></service-profile>\n' > "$cap/impex/install/services.xml"
mkdir -p "$cap/impex/uninstall"
printf '<services mode="delete"><service-credential service-id="MySvc" mode="delete"/></services>\n' > "$cap/impex/uninstall/services.xml"
assert_passes "fully configured profile passes" "$cap"

# Test 6: shorthand cb-enabled accepted
cap="$(mkcap)"; mkdir -p "$cap/impex/install"
printf '{"domain":"tax"}\n' > "$cap/commerce-app.json"
printf '<service-profile service-id="MySvc"><timeout-millis>5000</timeout-millis><rate-limit-enabled>true</rate-limit-enabled><cb-enabled>true</cb-enabled></service-profile>\n' > "$cap/impex/install/services.xml"
mkdir -p "$cap/impex/uninstall"
printf '<services mode="delete"><service-credential service-id="MySvc" mode="delete"/></services>\n' > "$cap/impex/uninstall/services.xml"
assert_passes "shorthand cb-enabled accepted" "$cap"

# Test 7: explicit false still blocks
cap="$(mkcap)"; mkdir -p "$cap/impex/install"
printf '{"domain":"tax"}\n' > "$cap/commerce-app.json"
printf '<service-profile service-id="MySvc"><timeout-millis>5000</timeout-millis><rate-limit-enabled>false</rate-limit-enabled><circuit-breaker-enabled>true</circuit-breaker-enabled></service-profile>\n' > "$cap/impex/install/services.xml"
mkdir -p "$cap/impex/uninstall"
printf '<services mode="delete"><service-credential service-id="MySvc" mode="delete"/></services>\n' > "$cap/impex/uninstall/services.xml"
assert_blocks "explicit false still blocks (strict)" "$cap"

# Test 8: rate-limit but no circuit breaker
cap="$(mkcap)"; mkdir -p "$cap/impex/install"
printf '{"domain":"tax"}\n' > "$cap/commerce-app.json"
printf '<service-profile service-id="MySvc"><timeout-millis>5000</timeout-millis><rate-limit-enabled>true</rate-limit-enabled></service-profile>\n' > "$cap/impex/install/services.xml"
mkdir -p "$cap/impex/uninstall"
printf '<services mode="delete"><service-credential service-id="MySvc" mode="delete"/></services>\n' > "$cap/impex/uninstall/services.xml"
assert_blocks "missing circuit breaker blocks" "$cap"

# Test 9: circuit breaker but no rate limiting
cap="$(mkcap)"; mkdir -p "$cap/impex/install"
printf '{"domain":"tax"}\n' > "$cap/commerce-app.json"
printf '<service-profile service-id="MySvc"><timeout-millis>5000</timeout-millis><circuit-breaker-enabled>true</circuit-breaker-enabled></service-profile>\n' > "$cap/impex/install/services.xml"
mkdir -p "$cap/impex/uninstall"
printf '<services mode="delete"><service-credential service-id="MySvc" mode="delete"/></services>\n' > "$cap/impex/uninstall/services.xml"
assert_blocks "missing rate limiting blocks" "$cap"

# Test 10: uninstall dir skipped
cap="$(mkcap)"; mkdir -p "$cap/impex/uninstall"
printf '<service-profile service-id="MySvc"><timeout-millis>5000</timeout-millis></service-profile>\n' > "$cap/impex/uninstall/services.xml"
printf '<services mode="delete"><service-credential service-id="MySvc" mode="delete"/></services>\n' >> "$cap/impex/uninstall/services.xml"
assert_passes "service profile in uninstall dir skipped" "$cap"

# Test 11: no service-profile tag — file skipped
cap="$(mkcap)"; mkdir -p "$cap/impex/install"
printf '<services><service-credential service-id="MySvc"/></services>\n' > "$cap/impex/install/creds.xml"
mkdir -p "$cap/impex/uninstall"
printf '<services mode="delete"><service-credential service-id="MySvc" mode="delete"/></services>\n' > "$cap/impex/uninstall/creds.xml"
assert_passes "file without service-profile skipped" "$cap"

# Test 12: no commerce-app.json — still blocks with default ideal values
cap="$(mkcap)"; mkdir -p "$cap/impex/install"
printf '<service-profile service-id="MySvc"><timeout-millis>5000</timeout-millis></service-profile>\n' > "$cap/impex/install/services.xml"
mkdir -p "$cap/impex/uninstall"
printf '<services mode="delete"><service-credential service-id="MySvc" mode="delete"/></services>\n' > "$cap/impex/uninstall/services.xml"
run_scan "$cap"
if [[ "$LAST_RC" -eq 1 ]] && echo "$LAST_OUTPUT" | grep -qF "All others"; then
  echo "  PASS: no commerce-app.json — blocks with default ideal values"
  PASS=$((PASS + 1))
else
  echo "  FAIL: no commerce-app.json (expected block + 'All others' in output, got exit $LAST_RC)"
  FAIL=$((FAIL + 1))
fi

echo ""

# ---------------------------------------------------------------------------
# S16: Session object access (WARN)
# ---------------------------------------------------------------------------
echo "--- S16: Session object access ---"

cap="$(mkcap)"; mkdir -p "$cap/hooks"
printf '{"hooks":[{"name":"sfcc.app.tax.calculate","script":"./hooks/tax.js"}]}\n' > "$cap/hooks.json"
printf "exports.calculate = function() { try { var S = require('dw/system/Session'); } catch(e) {} };\n" > "$cap/hooks/tax.js"
assert_warns "Session import in hook" "Session access" "$cap"

cap="$(mkcap)"; mkdir -p "$cap/hooks"
printf '{"hooks":[{"name":"sfcc.app.tax.calculate","script":"./hooks/tax.js"}]}\n' > "$cap/hooks.json"
printf 'exports.calculate = function() { try { var t = session.privacy.token; } catch(e) {} };\n' > "$cap/hooks/tax.js"
assert_warns "session.privacy access in hook" "Session access" "$cap"

cap="$(mkcap)"; mkdir -p "$cap/hooks"
printf '{"hooks":[{"name":"sfcc.app.tax.calculate","script":"./hooks/tax.js"}]}\n' > "$cap/hooks.json"
printf 'exports.calculate = function() { try { var d = session.custom.data; } catch(e) {} };\n' > "$cap/hooks/tax.js"
assert_warns "session.custom access in hook" "Session access" "$cap"

cap="$(mkcap)"; printf "var S = require('dw/system/Session');\n" > "$cap/util.js"
assert_no_warning "Session outside hooks is not checked" "Session access" "$cap"

cap="$(mkcap)"; printf "var S = require('dw/system/Session');\n" > "$cap/util.js"
assert_passes "HOOKS_FILES empty, S16 skipped" "$cap"

cap="$(mkcap)"; mkdir -p "$cap/hooks"
printf '{"hooks":[{"name":"sfcc.app.tax.calculate","script":"./hooks/tax.js"}]}\n' > "$cap/hooks.json"
printf 'exports.calculate = function() { try { return compute(); } catch(e) {} };\n' > "$cap/hooks/tax.js"
assert_no_warning "clean hook has no session warning" "Session access" "$cap"

echo ""

# ---------------------------------------------------------------------------
# P1: Service profile timeout (BLOCK)
# ---------------------------------------------------------------------------
echo "--- P1: Service profile timeout ---"

cap="$(mkcap)"; mkdir -p "$cap/impex/install"
printf '<service-profile service-id="MySvc"><rate-limit-enabled>true</rate-limit-enabled><circuit-breaker-enabled>true</circuit-breaker-enabled></service-profile>\n' > "$cap/impex/install/profiles.xml"
mkdir -p "$cap/impex/uninstall"
printf '<services mode="delete"><service-credential service-id="MySvc" mode="delete"/></services>\n' > "$cap/impex/uninstall/profiles.xml"
assert_blocks "service profile without timeout-millis blocks" "$cap"

cap="$(mkcap)"; mkdir -p "$cap/impex/install"
printf '<service-profile service-id="MySvc"><timeout-millis>5000</timeout-millis><rate-limit-enabled>true</rate-limit-enabled><circuit-breaker-enabled>true</circuit-breaker-enabled></service-profile>\n' > "$cap/impex/install/profiles.xml"
mkdir -p "$cap/impex/uninstall"
printf '<services mode="delete"><service-credential service-id="MySvc" mode="delete"/></services>\n' > "$cap/impex/uninstall/profiles.xml"
assert_passes "service profile with timeout passes" "$cap"

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
# Q2: Hook function exported (BLOCK)
# ---------------------------------------------------------------------------
echo "--- Q2: Hook function export ---"

cap="$(mkcap)"; mkdir -p "$cap/hooks"
printf '{"hooks":[{"name":"sfcc.app.tax.calculate","script":"./hooks/tax.js"}]}\n' > "$cap/hooks.json"
printf 'function calculate() { try { run(); } catch(e) {} }\n' > "$cap/hooks/tax.js"
assert_blocks "unexported hook function blocks" "$cap"

cap="$(mkcap)"; mkdir -p "$cap/hooks"
printf '{"hooks":[{"name":"sfcc.app.tax.calculate","script":"./hooks/tax.js"}]}\n' > "$cap/hooks.json"
printf 'exports.calculate = function() { try { run(); } catch(e) {} };\n' > "$cap/hooks/tax.js"
assert_no_warning "exported hook function — no export warning" "expects export" "$cap"

echo ""

# ---------------------------------------------------------------------------
# Q3: Error handling in hooks (BLOCK)
# ---------------------------------------------------------------------------
echo "--- Q3: Hook error handling ---"

cap="$(mkcap)"; mkdir -p "$cap/hooks"
printf '{"hooks":[{"name":"sfcc.app.tax.calculate","script":"./hooks/tax.js"}]}\n' > "$cap/hooks.json"
printf 'exports.calculate = function() { return 1; };\n' > "$cap/hooks/tax.js"
assert_blocks "hook without try/catch blocks" "$cap"

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

# Q4 service ID mismatch now blocks
cap="$(mkcap)"; mkdir -p "$cap/impex/install" "$cap/impex/uninstall"
printf '<services><service-credential service-id="svc1"/><service-credential service-id="svc2"/></services>\n' > "$cap/impex/install/services.xml"
printf '<services mode="delete"><service-credential service-id="svc1" mode="delete"/></services>\n' > "$cap/impex/uninstall/services.xml"
assert_blocks "service ID in install but missing from uninstall blocks" "$cap"

echo ""

# ---------------------------------------------------------------------------
# Q5: SITEID placeholder (BLOCK)
# ---------------------------------------------------------------------------
echo "--- Q5: SITEID placeholder ---"

cap="$(mkcap)"; printf '<site site-id="MySite"><prefs/></site>\n' > "$cap/prefs.xml"
assert_blocks "hardcoded site-id blocks" "$cap"

cap="$(mkcap)"; printf '<site site-id="SITEID"><prefs/></site>\n' > "$cap/prefs.xml"
assert_no_warning "SITEID placeholder — no site-id warning" "Hardcoded site-id" "$cap"

echo ""

# ---------------------------------------------------------------------------
# Q6: Absolute paths (BLOCK)
# ---------------------------------------------------------------------------
echo "--- Q6: Absolute paths ---"

cap="$(mkcap)"; printf "var p = '/tmp/data';\n" > "$cap/app.js"
assert_blocks "absolute /tmp/ path blocks" "$cap"

cap="$(mkcap)"; printf "var p = './data';\n" > "$cap/app.js"
assert_no_warning "relative path — no absolute path warning" "Absolute path" "$cap"

echo ""

# ---------------------------------------------------------------------------
# Q7: console.log (BLOCK)
# ---------------------------------------------------------------------------
echo "--- Q7: console.log ---"

cap="$(mkcap)"; printf 'console.log("debug");\n' > "$cap/cart.js"
assert_blocks "console.log blocks" "$cap"

cap="$(mkcap)"; printf 'console.debug("test");\n' > "$cap/cart.js"
assert_blocks "console.debug blocks" "$cap"

cap="$(mkcap)"; printf '// console.log("commented out");\n' > "$cap/cart.js"
assert_passes "console.log in line comment is ignored" "$cap"

echo ""

# ---------------------------------------------------------------------------
# Combination: warnings don't block, one block + warn = exit 1
# ---------------------------------------------------------------------------
echo "--- Combination ---"

# Multiple warnings don't block (Math.random + session in hook)
cap="$(mkcap)"; mkdir -p "$cap/hooks"
printf '{"hooks":[{"name":"sfcc.app.tax.calculate","script":"./hooks/tax.js"}]}\n' > "$cap/hooks.json"
printf 'exports.calculate = function() { try { var r = Math.random(); var t = session.privacy.token; return r; } catch(e) {} };\n' > "$cap/hooks/tax.js"
run_scan "$cap"
if [[ "$LAST_RC" -eq 0 ]]; then echo "  PASS: multiple WARNs don't block (exit 0)"; PASS=$((PASS + 1))
else echo "  FAIL: multiple WARNs don't block (expected exit 0, got $LAST_RC)"; FAIL=$((FAIL + 1)); fi

# One BLOCK + one WARN = exit 1
cap="$(mkcap)"; printf 'var r = Math.random();\nvar x = eval("code");\n' > "$cap/app.js"
run_scan "$cap"
if [[ "$LAST_RC" -eq 1 ]]; then echo "  PASS: one BLOCK + one WARN = exit 1"; PASS=$((PASS + 1))
else echo "  FAIL: one BLOCK + one WARN = exit 1 (got $LAST_RC)"; FAIL=$((FAIL + 1)); fi

# Empty CAP directory
cap="$(mkcap)"
assert_clean "empty dir is clean" "$cap"

echo ""
echo "=== Results: $PASS passed, $FAIL failed, $BUGS known bugs ==="
[[ "$FAIL" -eq 0 ]]
