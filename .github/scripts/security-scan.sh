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

echo "=== Security & Quality Scan ==="
echo "CAP root: $CAP_ROOT"
echo "JS/DS files: ${#JS_FILES[@]}"
echo "TS/TSX files: ${#TS_FILES[@]}"
echo "XML files: ${#XML_FILES[@]}"
echo "Code files: ${#ALL_CODE_FILES[@]}"
echo ""

# ============================= SECURITY =====================================

echo "--- Security Checks ---"

# S1: eval() / new Function() — code injection sinks (BLOCK)
for f in ${ALL_CODE_FILES[@]+"${ALL_CODE_FILES[@]}"}; do
  [[ -z "$f" ]] && continue
  while IFS= read -r line; do
    block "$f" "eval() detected — code injection risk: $line"
  done < <(grep -nE '\beval\s*\(' "$f" 2>/dev/null | grep -v '^\s*//' | grep -v '^\s*\*' | head -5)

  while IFS= read -r line; do
    block "$f" "new Function() detected — code injection risk: $line"
  done < <(grep -nE '\bnew\s+Function\s*\(' "$f" 2>/dev/null | grep -v '^\s*//' | grep -v '^\s*\*' | head -5)
done

# S2: Dynamic require() — non-literal string argument (BLOCK)
for f in ${ALL_CODE_FILES[@]+"${ALL_CODE_FILES[@]}"}; do
  [[ -z "$f" ]] && continue
  # Match require( but not require('...' or require("...
  while IFS= read -r line; do
    block "$f" "Dynamic require() with concatenation detected: $line"
  done < <(grep -nE 'require\s*\([^)]*\+' "$f" 2>/dev/null | grep -v '^\s*//' | head -5)
done

# S3: innerHTML assignment (BLOCK)
for f in ${ALL_CODE_FILES[@]+"${ALL_CODE_FILES[@]}"}; do
  [[ -z "$f" ]] && continue
  while IFS= read -r line; do
    block "$f" "innerHTML assignment detected — XSS risk: $line"
  done < <(grep -nE '\.innerHTML\s*=' "$f" 2>/dev/null | grep -v '^\s*//' | head -5)
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
    done < <(grep -nE "$pattern" "$f" 2>/dev/null | grep -v '^\s*//' | head -3)
  done
done

# S5: Hardcoded secrets in XML (impex credentials) (BLOCK)
for f in ${XML_FILES[@]+"${XML_FILES[@]}"}; do
  [[ -z "$f" ]] && continue
  # Check <password> or <user-id> values that look like real credentials (length > 20, not a placeholder)
  while IFS= read -r line; do
    block "$f" "Possible hardcoded credential in XML: $line"
  done < <(grep -nE '<password>[^<]{20,}</password>' "$f" 2>/dev/null | grep -vi 'YOUR_\|PLACEHOLDER\|CHANGEME\|TODO\|xxx' | head -3)
done

# S6: Math.random() for potentially security-sensitive use (WARN)
for f in ${ALL_CODE_FILES[@]+"${ALL_CODE_FILES[@]}"}; do
  [[ -z "$f" ]] && continue
  while IFS= read -r line; do
    warn "$f" "Math.random() detected — not cryptographically secure: $line"
  done < <(grep -nE 'Math\.random\s*\(' "$f" 2>/dev/null | grep -v '^\s*//' | head -3)
done

# S7: Credentials outside service framework (WARN)
for f in ${JS_FILES[@]+"${JS_FILES[@]}"}; do
  [[ -z "$f" ]] && continue
  while IFS= read -r line; do
    warn "$f" "Inline Authorization header — use service framework instead: $line"
  done < <(grep -nE 'setRequestHeader\s*\(\s*['\''"]Authorization' "$f" 2>/dev/null | head -3)
done

echo ""

# ============================ PERFORMANCE ===================================

echo "--- Performance Checks ---"

# P1: console.log in production cartridge code (WARN)
for f in ${JS_FILES[@]+"${JS_FILES[@]}"}; do
  [[ -z "$f" ]] && continue
  while IFS= read -r line; do
    warn "$f" "console.log/debug statement in cartridge code — use dw.system.Logger: $line"
  done < <(grep -nE 'console\.(log|debug|info|warn|error)\s*\(' "$f" 2>/dev/null | grep -v '^\s*//' | head -5)
done

# P2: Missing timeout on HTTPClient calls (WARN)
for f in ${JS_FILES[@]+"${JS_FILES[@]}"}; do
  [[ -z "$f" ]] && continue
  if grep -lE 'HTTPClient' "$f" 2>/dev/null >/dev/null; then
    if ! grep -qE 'setTimeout\|setConnectionTimeout\|\.setTimeout' "$f" 2>/dev/null; then
      warn "$f" "HTTPClient used without explicit timeout configuration"
    fi
  fi
done

# P3: Missing timeout in service profile XML (WARN)
# Only check install XMLs — uninstall uses mode="delete" and won't define profiles
for f in ${XML_FILES[@]+"${XML_FILES[@]}"}; do
  [[ -z "$f" ]] && continue
  case "$f" in */uninstall/*) continue ;; esac
  if grep -qE '<service-profile' "$f" 2>/dev/null; then
    if ! grep -qE '<timeout-millis>' "$f" 2>/dev/null; then
      warn "$f" "Service profile missing <timeout-millis> — requests may hang indefinitely"
    fi
  fi
done

echo ""

# ============================== QUALITY =====================================

echo "--- Quality Checks ---"

# Q1: Hook scripts referenced in hooks.json must exist (BLOCK)
HOOKS_FILES=()
while IFS= read -r f; do HOOKS_FILES+=("$f"); done < <(find "$CAP_ROOT" -type f -name 'hooks.json' 2>/dev/null || true)
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

# Q2: Hook functions must be exported (WARN)
for hooks_file in ${HOOKS_FILES[@]+"${HOOKS_FILES[@]}"}; do
  [[ -z "$hooks_file" ]] && continue
  hooks_dir="$(dirname "$hooks_file")"

  while IFS= read -r entry; do
    script="$(jq -r '.script // empty' <<< "$entry" 2>/dev/null)"
    # Extract function name from hook name (last segment after .)
    hook_name="$(jq -r '.name // empty' <<< "$entry" 2>/dev/null)"
    [[ -z "$script" || -z "$hook_name" ]] && continue

    rel="${script#./}"
    target="$hooks_dir/$rel"
    [[ -f "$target" ]] || continue

    # Extract the expected export function from the hook name
    # e.g., sfcc.app.tax.calculate -> calculate
    func_name="${hook_name##*.}"
    if ! grep -qE "exports\.$func_name\s*=|module\.exports.*$func_name" "$target" 2>/dev/null; then
      warn "$hooks_file" "Hook '$hook_name' expects export '$func_name' but not found in $script"
    fi
  done < <(jq -c '.hooks[]?' "$hooks_file" 2>/dev/null)
done

# Q3: Missing error handling in hook scripts (WARN)
for hooks_file in ${HOOKS_FILES[@]+"${HOOKS_FILES[@]}"}; do
  [[ -z "$hooks_file" ]] && continue
  hooks_dir="$(dirname "$hooks_file")"

  while IFS= read -r script_path; do
    [[ -z "$script_path" || "$script_path" == "null" ]] && continue
    rel="${script_path#./}"
    target="$hooks_dir/$rel"
    [[ -f "$target" ]] || continue

    if ! grep -qE '\btry\b' "$target" 2>/dev/null; then
      warn "$target" "Hook script has no try/catch error handling"
    fi
  done < <(jq -r '.hooks[]?.script // empty' "$hooks_file" 2>/dev/null)
done

# Q4: Impex install/uninstall symmetry for services (BLOCK)
install_services="$CAP_ROOT/impex/install/services.xml"
uninstall_services="$CAP_ROOT/impex/uninstall/services.xml"
# Also check one level deeper if the structure uses a wrapper dir
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
        warn "$uninstall_services" "Service $id in install but missing from uninstall"
      fi
    done
  fi
fi

# Q5: SITEID placeholder check in impex (WARN)
for f in ${XML_FILES[@]+"${XML_FILES[@]}"}; do
  [[ -z "$f" ]] && continue
  while IFS= read -r line; do
    warn "$f" "Hardcoded site-id — use SITEID placeholder: $line"
  done < <(grep -nE 'site-id="[^"]*"' "$f" 2>/dev/null | grep -v 'SITEID' | grep -v 'mode="delete"' | head -3)
done

# Q6: Absolute paths in code (WARN)
for f in ${ALL_CODE_FILES[@]+"${ALL_CODE_FILES[@]}"}; do
  [[ -z "$f" ]] && continue
  while IFS= read -r line; do
    warn "$f" "Absolute path detected — use relative paths: $line"
  done < <(grep -nE "['\"]/usr/|['\"]/tmp/|['\"]/home/|['\"]/var/|['\"]C:\\\\" "$f" 2>/dev/null | grep -v '^\s*//' | head -3)
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
