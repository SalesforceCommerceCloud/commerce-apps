#!/bin/bash
# =============================================================================
# Security, Performance & Quality scan for Commerce App Packages (CAPs)
#
# Usage: ./security-scan.sh <extracted-cap-root-dir>
#
# Exit codes:
#   0 = all checks passed (warnings may still be present)
#   1 = one or more blocking findings
#
# Finding severity:
#   BLOCK  — prevents merge (exit 1)
#   WARN   — advisory, surfaced in PR but non-blocking
# =============================================================================

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <extracted-cap-root-dir>"
  exit 1
fi

CAP_ROOT="$1"
if [[ ! -d "$CAP_ROOT" ]]; then
  echo "::error::CAP root directory does not exist: $CAP_ROOT"
  exit 1
fi

BLOCKS=0
WARNINGS=0

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
block() {
  local file="$1" msg="$2"
  echo "::error file=$file::$msg"
  BLOCKS=$((BLOCKS + 1))
}

warn() {
  local file="$1" msg="$2"
  echo "::warning file=$file::$msg"
  WARNINGS=$((WARNINGS + 1))
}

# Filter out lines that are comments. Works with grep -n output (N:// or N:  //)
# and block comments (N: * or N:/*). Strips the line-number prefix before checking.
strip_comments() {
  grep -vE '^[0-9]+:\s*//' | grep -vE '^[0-9]+:\s*\*' | grep -vE '^[0-9]+:\s*/\*'
}

# Collect JS/DS files (cartridge server-side scripts + storefront-next TS)
# Using while-read for macOS bash 3 compatibility (no mapfile)
JS_FILES=()
while IFS= read -r f; do JS_FILES+=("$f"); done < <(find "$CAP_ROOT" -type f \( -name '*.js' -o -name '*.ds' \) ! -path '*/node_modules/*' 2>/dev/null || true)
TS_FILES=()
while IFS= read -r f; do TS_FILES+=("$f"); done < <(find "$CAP_ROOT" -type f \( -name '*.ts' -o -name '*.tsx' \) ! -path '*/node_modules/*' 2>/dev/null || true)
ALL_CODE_FILES=()
while IFS= read -r f; do [[ -n "$f" ]] && ALL_CODE_FILES+=("$f"); done < <(printf '%s\n' "${JS_FILES[@]+${JS_FILES[@]}}" "${TS_FILES[@]+${TS_FILES[@]}}" | sort -u)
XML_FILES=()
while IFS= read -r f; do XML_FILES+=("$f"); done < <(find "$CAP_ROOT" -type f -name '*.xml' 2>/dev/null || true)
JSON_FILES=()
while IFS= read -r f; do JSON_FILES+=("$f"); done < <(find "$CAP_ROOT" -type f -name '*.json' 2>/dev/null || true)
ISML_FILES=()
while IFS= read -r f; do ISML_FILES+=("$f"); done < <(find "$CAP_ROOT" -type f -name '*.isml' 2>/dev/null || true)

# Read app domain from commerce-app.json (used by S15 for recommended values)
APP_DOMAIN=""
COMMERCE_APP_JSON="$(find "$CAP_ROOT" -maxdepth 2 -name 'commerce-app.json' -print -quit 2>/dev/null || true)"
if [[ -n "$COMMERCE_APP_JSON" && -f "$COMMERCE_APP_JSON" ]]; then
  APP_DOMAIN="$(jq -r '.domain // empty' "$COMMERCE_APP_JSON" 2>/dev/null || true)"
fi

# Collect hook script paths for hook-scoped rules (S13, S16)
HOOK_SCRIPT_FILES=()
HOOKS_FILES=()
while IFS= read -r f; do HOOKS_FILES+=("$f"); done < <(find "$CAP_ROOT" -type f -name 'hooks.json' 2>/dev/null || true)
for hooks_file in ${HOOKS_FILES[@]+"${HOOKS_FILES[@]}"}; do
  [[ -z "$hooks_file" ]] && continue
  hooks_dir="$(dirname "$hooks_file")"
  while IFS= read -r script_path; do
    [[ -z "$script_path" || "$script_path" == "null" ]] && continue
    rel="${script_path#./}"
    target="$hooks_dir/$rel"
    [[ -f "$target" ]] && HOOK_SCRIPT_FILES+=("$target")
  done < <(jq -r '.hooks[]?.script // empty' "$hooks_file" 2>/dev/null)
done

echo "=== Security & Quality Scan ==="
echo "CAP root: $CAP_ROOT"
echo "JS/DS files: ${#JS_FILES[@]}"
echo "TS/TSX files: ${#TS_FILES[@]}"
echo "XML files: ${#XML_FILES[@]}"
echo "ISML files: ${#ISML_FILES[@]}"
echo "Code files: ${#ALL_CODE_FILES[@]}"
echo "App domain: ${APP_DOMAIN:-<not detected>}"
echo ""

# ============================= SECURITY =====================================

echo "--- Security Checks ---"

# S1: eval() / new Function() — code injection sinks (BLOCK)
for f in ${ALL_CODE_FILES[@]+"${ALL_CODE_FILES[@]}"}; do
  [[ -z "$f" ]] && continue
  while IFS= read -r line; do
    block "$f" "eval() detected — code injection risk: $line"
  done < <(grep -nE '\beval\s*\(' "$f" 2>/dev/null | strip_comments | head -5)

  while IFS= read -r line; do
    block "$f" "new Function() detected — code injection risk: $line"
  done < <(grep -nE '\bnew\s+Function\s*\(' "$f" 2>/dev/null | strip_comments | head -5)
done

# S2: Dynamic require() — non-literal string argument (BLOCK)
for f in ${ALL_CODE_FILES[@]+"${ALL_CODE_FILES[@]}"}; do
  [[ -z "$f" ]] && continue
  while IFS= read -r line; do
    block "$f" "Dynamic require() with concatenation detected: $line"
  done < <(grep -nE 'require\s*\([^)]*\+' "$f" 2>/dev/null | strip_comments | head -5)
done

# S3: innerHTML assignment (BLOCK)
for f in ${ALL_CODE_FILES[@]+"${ALL_CODE_FILES[@]}"}; do
  [[ -z "$f" ]] && continue
  while IFS= read -r line; do
    block "$f" "innerHTML assignment detected — XSS risk: $line"
  done < <(grep -nE '\.innerHTML\s*=' "$f" 2>/dev/null | strip_comments | head -5)
done

# S4: Hardcoded secret patterns (BLOCK)
SECRET_PATTERNS=(
  '(sk|pk)_(live|test)_[A-Za-z0-9]{10,}'
  'Bearer\s+[A-Za-z0-9._\-]{20,}'
  'AKIA[0-9A-Z]{16}'                          # AWS access key
  'ghp_[A-Za-z0-9]{36}'                       # GitHub PAT
  'xox[bpsa]-[A-Za-z0-9\-]{10,}'             # Slack token
  '-----BEGIN (RSA |EC )?PRIVATE KEY-----'
)

for f in ${ALL_CODE_FILES[@]+"${ALL_CODE_FILES[@]}"}; do
  [[ -z "$f" ]] && continue
  for pattern in "${SECRET_PATTERNS[@]}"; do
    while IFS= read -r line; do
      block "$f" "Possible hardcoded secret detected: $line"
    done < <(grep -nE -- "$pattern" "$f" 2>/dev/null | strip_comments | head -3)
  done
done

# S5: Hardcoded secrets in XML (impex credentials) (BLOCK)
for f in ${XML_FILES[@]+"${XML_FILES[@]}"}; do
  [[ -z "$f" ]] && continue
  while IFS= read -r line; do
    block "$f" "Possible hardcoded credential in XML: $line"
  done < <(grep -nE '<password>[^<]{20,}</password>' "$f" 2>/dev/null | grep -vi 'YOUR_\|PLACEHOLDER\|CHANGEME\|TODO\|xxx' | head -3)
done

# S6: Math.random() for potentially security-sensitive use (WARN)
for f in ${ALL_CODE_FILES[@]+"${ALL_CODE_FILES[@]}"}; do
  [[ -z "$f" ]] && continue
  while IFS= read -r line; do
    warn "$f" "Math.random() detected — not cryptographically secure: $line"
  done < <(grep -nE 'Math\.random\s*\(' "$f" 2>/dev/null | strip_comments | head -3)
done

# S7: Credentials outside service framework (BLOCK)
for f in ${JS_FILES[@]+"${JS_FILES[@]}"}; do
  [[ -z "$f" ]] && continue
  while IFS= read -r line; do
    block "$f" "Inline Authorization header — use service framework instead: $line"
  done < <(grep -nE 'setRequestHeader\s*\(\s*['\''"]Authorization' "$f" 2>/dev/null | head -3)
done

# S8: Additional DOM sinks — outerHTML, document.write, insertAdjacentHTML (BLOCK)
for f in ${ALL_CODE_FILES[@]+"${ALL_CODE_FILES[@]}"}; do
  [[ -z "$f" ]] && continue
  while IFS= read -r line; do
    block "$f" "outerHTML assignment detected — XSS risk: $line"
  done < <(grep -nE '\.outerHTML\s*=' "$f" 2>/dev/null | strip_comments | head -5)

  while IFS= read -r line; do
    block "$f" "document.write() detected — XSS risk: $line"
  done < <(grep -nE 'document\[?['\''"]?write(ln)?['\''"]?\]?\s*\(' "$f" 2>/dev/null | strip_comments | head -5)

  while IFS= read -r line; do
    block "$f" "insertAdjacentHTML() detected — XSS risk: $line"
  done < <(grep -nE '\.insertAdjacentHTML\s*\(' "$f" 2>/dev/null | strip_comments | head -5)
done

# S9: ISML template injection — encoding="off" (BLOCK)
for f in ${ISML_FILES[@]+"${ISML_FILES[@]}"}; do
  [[ -z "$f" ]] && continue
  while IFS= read -r line; do
    block "$f" "ISML isprint with encoding=\"off\" — XSS risk: $line"
  done < <(grep -nE '<isprint[^>]+encoding\s*=\s*"off"' "$f" 2>/dev/null | head -5)
done

# S10: Secret files in package (BLOCK)
while IFS= read -r f; do
  block "$f" "Secret file detected in package — must not ship key/env files"
done < <(find "$CAP_ROOT" -type f \( -name '*.env' -o -name '.env' -o -name '*.key' -o -name '*.pem' -o -name '*.p12' -o -name '*.pfx' -o -name '*.jks' \) 2>/dev/null || true)

# S11: Direct HTTPClient usage — must use service framework (BLOCK)
for f in ${ALL_CODE_FILES[@]+"${ALL_CODE_FILES[@]}"}; do
  [[ -z "$f" ]] && continue
  while IFS= read -r line; do
    block "$f" "Direct HTTPClient usage — must use service framework: $line"
  done < <(grep -nE '\bHTTPClient\b' "$f" 2>/dev/null | strip_comments | head -5)
done

# S12: Sensitive data in logs — PII field names in Logger calls (WARN)
for f in ${ALL_CODE_FILES[@]+"${ALL_CODE_FILES[@]}"}; do
  [[ -z "$f" ]] && continue
  while IFS= read -r line; do
    warn "$f" "Possible PII in log statement: $line"
  done < <(grep -nE '(Logger|log)\.(info|debug|error|warn|trace)\s*\(.*\b(creditCard|cardNumber|cvv|password|passwd|secret|ssn|socialSecurity|taxId|bankAccount)\b' "$f" 2>/dev/null | strip_comments | head -5)
done

# S13: Blocking/sleep in hook scripts — setTimeout/setInterval (BLOCK)
for f in ${HOOK_SCRIPT_FILES[@]+"${HOOK_SCRIPT_FILES[@]}"}; do
  [[ -z "$f" ]] && continue
  while IFS= read -r line; do
    block "$f" "setTimeout/setInterval in hook script — blocking call: $line"
  done < <(grep -nE '\b(setTimeout|setInterval)\s*\(' "$f" 2>/dev/null | strip_comments | head -5)
done

# S14: Unbounded loops — while(true)/for(;;) without break/return within 20 lines (BLOCK)
for f in ${ALL_CODE_FILES[@]+"${ALL_CODE_FILES[@]}"}; do
  [[ -z "$f" ]] && continue
  while IFS= read -r match; do
    line_num="${match%%:*}"
    end_line=$((line_num + 20))
    if ! sed -n "${line_num},${end_line}p" "$f" 2>/dev/null | grep -qE '\b(break|return)\b'; then
      block "$f" "Unbounded loop without break/return within 20 lines (line $line_num)"
    fi
  done < <(grep -nE 'while\s*\(\s*true\s*\)|for\s*\(\s*;\s*;\s*\)' "$f" 2>/dev/null | strip_comments)
done

# S15: Missing rate limiting and circuit breaker on service profiles (BLOCK)
# Applies to ALL apps with service profiles
S15_IDEAL_TAX="    <timeout-millis>5000</timeout-millis>\n    <rate-limit-enabled>true</rate-limit-enabled>\n    <rate-limit-calls>100</rate-limit-calls>\n    <rate-limit-millis>1000</rate-limit-millis>\n    <cb-enabled>true</cb-enabled>\n    <cb-calls>3</cb-calls>\n    <cb-millis>10000</cb-millis>"
S15_IDEAL_PAYMENT="    <timeout-millis>10000</timeout-millis>\n    <rate-limit-enabled>true</rate-limit-enabled>\n    <rate-limit-calls>50</rate-limit-calls>\n    <rate-limit-millis>1000</rate-limit-millis>\n    <cb-enabled>true</cb-enabled>\n    <cb-calls>3</cb-calls>\n    <cb-millis>10000</cb-millis>"
S15_IDEAL_FRAUD="    <timeout-millis>5000</timeout-millis>\n    <rate-limit-enabled>true</rate-limit-enabled>\n    <rate-limit-calls>100</rate-limit-calls>\n    <rate-limit-millis>1000</rate-limit-millis>\n    <cb-enabled>true</cb-enabled>\n    <cb-calls>3</cb-calls>\n    <cb-millis>10000</cb-millis>"
S15_IDEAL_SHIPPING="    <timeout-millis>5000</timeout-millis>\n    <rate-limit-enabled>true</rate-limit-enabled>\n    <rate-limit-calls>100</rate-limit-calls>\n    <rate-limit-millis>1000</rate-limit-millis>\n    <cb-enabled>true</cb-enabled>\n    <cb-calls>5</cb-calls>\n    <cb-millis>10000</cb-millis>"
S15_IDEAL_DEFAULT="    <timeout-millis>10000</timeout-millis>\n    <rate-limit-enabled>true</rate-limit-enabled>\n    <rate-limit-calls>100</rate-limit-calls>\n    <rate-limit-millis>1000</rate-limit-millis>\n    <cb-enabled>true</cb-enabled>\n    <cb-calls>5</cb-calls>\n    <cb-millis>10000</cb-millis>"

s15_get_ideal() {
  case "$APP_DOMAIN" in
    tax) printf '%b' "$S15_IDEAL_TAX" ;;
    payment) printf '%b' "$S15_IDEAL_PAYMENT" ;;
    fraud) printf '%b' "$S15_IDEAL_FRAUD" ;;
    shipping) printf '%b' "$S15_IDEAL_SHIPPING" ;;
    *) printf '%b' "$S15_IDEAL_DEFAULT" ;;
  esac
}

for f in ${XML_FILES[@]+"${XML_FILES[@]}"}; do
  [[ -z "$f" ]] && continue
  case "$f" in */uninstall/*) continue ;; esac
  if grep -qE '<service-profile' "$f" 2>/dev/null; then
    has_rate_limit=false
    has_circuit_breaker=false
    if grep -qE '<rate-limit-enabled>true</rate-limit-enabled>' "$f" 2>/dev/null; then
      has_rate_limit=true
    fi
    if grep -qE '<circuit-breaker-enabled>true</circuit-breaker-enabled>|<cb-enabled>true</cb-enabled>' "$f" 2>/dev/null; then
      has_circuit_breaker=true
    fi
    if [[ "$has_rate_limit" == "false" || "$has_circuit_breaker" == "false" ]]; then
      ideal="$(s15_get_ideal)"
      domain_label="${APP_DOMAIN:-All others}"
      block "$f" "Service profile missing rate limiting and/or circuit breaker. Recommended config for ${domain_label} apps:
${ideal}"
    fi
  fi
done

# S16: Session object access in hook scripts (WARN)
for f in ${HOOK_SCRIPT_FILES[@]+"${HOOK_SCRIPT_FILES[@]}"}; do
  [[ -z "$f" ]] && continue
  while IFS= read -r line; do
    warn "$f" "Session access in hook script — review for data leakage: $line"
  done < <(grep -nE 'dw\.system\.Session|require.*dw/system/Session|session\.(privacy|custom|forms)' "$f" 2>/dev/null | head -5)
done

echo ""

# ============================ PERFORMANCE ===================================

echo "--- Performance Checks ---"

# P1: Missing timeout in service profile XML (BLOCK)
for f in ${XML_FILES[@]+"${XML_FILES[@]}"}; do
  [[ -z "$f" ]] && continue
  case "$f" in */uninstall/*) continue ;; esac
  if grep -qE '<service-profile' "$f" 2>/dev/null; then
    if ! grep -qE '<timeout-millis>' "$f" 2>/dev/null; then
      block "$f" "Service profile missing <timeout-millis> — requests may hang indefinitely"
    fi
  fi
done

echo ""

# ============================== QUALITY =====================================

echo "--- Quality Checks ---"

# Q1: Hook scripts referenced in hooks.json must exist (BLOCK)
for hooks_file in ${HOOKS_FILES[@]+"${HOOKS_FILES[@]}"}; do
  [[ -z "$hooks_file" ]] && continue
  hooks_dir="$(dirname "$hooks_file")"

  while IFS= read -r script_path; do
    [[ -z "$script_path" || "$script_path" == "null" ]] && continue
    rel="${script_path#./}"
    target="$hooks_dir/$rel"
    if [[ ! -f "$target" ]]; then
      block "$hooks_file" "Hook script does not exist: $script_path (resolved: $target)"
    fi
  done < <(jq -r '.hooks[]?.script // empty' "$hooks_file" 2>/dev/null)
done

# Q2: Hook functions must be exported (BLOCK)
for hooks_file in ${HOOKS_FILES[@]+"${HOOKS_FILES[@]}"}; do
  [[ -z "$hooks_file" ]] && continue
  hooks_dir="$(dirname "$hooks_file")"

  while IFS= read -r entry; do
    script="$(jq -r '.script // empty' <<< "$entry" 2>/dev/null)"
    hook_name="$(jq -r '.name // empty' <<< "$entry" 2>/dev/null)"
    [[ -z "$script" || -z "$hook_name" ]] && continue

    rel="${script#./}"
    target="$hooks_dir/$rel"
    [[ -f "$target" ]] || continue

    func_name="${hook_name##*.}"
    if ! grep -qE "exports\.$func_name\s*=|module\.exports.*$func_name" "$target" 2>/dev/null; then
      block "$hooks_file" "Hook '$hook_name' expects export '$func_name' but not found in $script"
    fi
  done < <(jq -c '.hooks[]?' "$hooks_file" 2>/dev/null)
done

# Q3: Missing error handling in hook scripts (BLOCK)
for hooks_file in ${HOOKS_FILES[@]+"${HOOKS_FILES[@]}"}; do
  [[ -z "$hooks_file" ]] && continue
  hooks_dir="$(dirname "$hooks_file")"

  while IFS= read -r script_path; do
    [[ -z "$script_path" || "$script_path" == "null" ]] && continue
    rel="${script_path#./}"
    target="$hooks_dir/$rel"
    [[ -f "$target" ]] || continue

    if ! grep -qE '\btry\b' "$target" 2>/dev/null; then
      block "$target" "Hook script has no try/catch error handling"
    fi
  done < <(jq -r '.hooks[]?.script // empty' "$hooks_file" 2>/dev/null)
done

# Q4: Impex install/uninstall symmetry for services (BLOCK)
install_services="$CAP_ROOT/impex/install/services.xml"
uninstall_services="$CAP_ROOT/impex/uninstall/services.xml"
if [[ ! -f "$install_services" ]]; then
  install_services="$(find "$CAP_ROOT" -path '*/impex/install/services.xml' -print -quit 2>/dev/null || true)"
fi
if [[ ! -f "$uninstall_services" ]]; then
  uninstall_services="$(find "$CAP_ROOT" -path '*/impex/uninstall/services.xml' -print -quit 2>/dev/null || true)"
fi

if [[ -n "$install_services" && -f "$install_services" ]]; then
  if [[ -z "$uninstall_services" || ! -f "$uninstall_services" ]]; then
    block "$install_services" "install/services.xml exists but uninstall/services.xml is missing"
  else
    if ! grep -qE 'mode="delete"' "$uninstall_services" 2>/dev/null; then
      block "$uninstall_services" "uninstall/services.xml missing mode=\"delete\" — services won't be cleaned up"
    fi

    # Check that service IDs in install match uninstall
    install_ids=()
    while IFS= read -r id; do install_ids+=("$id"); done < <(grep -oE 'service-id="[^"]+"' "$install_services" 2>/dev/null | sort -u)
    uninstall_ids=()
    while IFS= read -r id; do uninstall_ids+=("$id"); done < <(grep -oE 'service-id="[^"]+"' "$uninstall_services" 2>/dev/null | sort -u)
    for id in "${install_ids[@]}"; do
      found=false
      for uid in "${uninstall_ids[@]}"; do
        [[ "$id" == "$uid" ]] && found=true && break
      done
      if [[ "$found" == "false" ]]; then
        block "$uninstall_services" "Service $id in install but missing from uninstall"
      fi
    done
  fi
fi

# Q5: SITEID placeholder check in impex (BLOCK)
for f in ${XML_FILES[@]+"${XML_FILES[@]}"}; do
  [[ -z "$f" ]] && continue
  while IFS= read -r line; do
    block "$f" "Hardcoded site-id — use SITEID placeholder: $line"
  done < <(grep -nE 'site-id="[^"]*"' "$f" 2>/dev/null | grep -v 'SITEID' | grep -v 'mode="delete"' | head -3)
done

# Q6: Absolute paths in code (BLOCK)
for f in ${ALL_CODE_FILES[@]+"${ALL_CODE_FILES[@]}"}; do
  [[ -z "$f" ]] && continue
  while IFS= read -r line; do
    block "$f" "Absolute path detected — use relative paths: $line"
  done < <(grep -nE "['\"]/usr/|['\"]/tmp/|['\"]/home/|['\"]/var/|['\"]C:\\\\" "$f" 2>/dev/null | strip_comments | head -3)
done

# Q7: console.log in production cartridge code (BLOCK)
for f in ${JS_FILES[@]+"${JS_FILES[@]}"}; do
  [[ -z "$f" ]] && continue
  while IFS= read -r line; do
    block "$f" "console.log/debug statement in cartridge code — use dw.system.Logger: $line"
  done < <(grep -nE 'console\.(log|debug|info|warn|error)\s*\(' "$f" 2>/dev/null | strip_comments | head -5)
done

echo ""

# ============================= SUMMARY ======================================

echo "=== Scan Complete ==="
echo "Blocking findings: $BLOCKS"
echo "Warnings: $WARNINGS"

if [[ $BLOCKS -gt 0 ]]; then
  echo ""
  echo "❌ FAILED — $BLOCKS blocking finding(s) must be resolved before merge"
  exit 1
fi

if [[ $WARNINGS -gt 0 ]]; then
  echo ""
  echo "⚠️  PASSED with $WARNINGS warning(s) — review recommended"
  exit 0
fi

echo ""
echo "✅ PASSED — no findings"
exit 0
