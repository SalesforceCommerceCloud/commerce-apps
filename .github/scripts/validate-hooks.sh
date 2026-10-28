#!/usr/bin/env bash
# Validate the backend extension points (hooks.json) of a packaged commerce app against
# .github/config/domain-hooks.json. Usage: validate-hooks.sh <zip_path>
#   HOOKS_CONFIG    override config path
#   ROOT_MANIFEST   override root manifest path
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${HOOKS_CONFIG:-$SCRIPT_DIR/../config/domain-hooks.json}"
ROOT_MANIFEST="${ROOT_MANIFEST:-commerce-apps-manifest/manifest.json}"
ZIP="${1:?usage: validate-hooks.sh <zip_path>}"

ERRORS=0
LEVEL="error"   # severity for rule violations in the current domain

report() { # $1 = severity (error|warning), $2 = file, $3 = message
  echo "::$1 file=$2::$3"
  [[ "$1" == "error" ]] && ERRORS=$((ERRORS + 1))
  return 0
}
violation() { report "$LEVEL" "$ZIP" "$1"; }

domain="$(cut -d/ -f1 <<< "$ZIP")"
app_id="$(cut -d/ -f2 <<< "$ZIP")"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
unzip -q "$ZIP" -d "$tmpdir"

# --- commerce-app.json sanity (name/domain) and domain consistency ---
cap="$(find "$tmpdir" -name commerce-app.json -print -quit)"
if [[ -n "$cap" ]]; then
  cap_domain="$(jq -r '.domain // empty' "$cap")"
  if [[ -n "$cap_domain" && "$cap_domain" != "$domain" ]]; then
    report error "$ZIP" "commerce-app.json domain \"$cap_domain\" does not match directory domain \"$domain\""
  fi
  # The platform reads only "name" and silently ignores it when blank or over 256 UTF-8 bytes.
  if jq -e 'has("name")' "$cap" > /dev/null; then
    name="$(jq -r '.name // ""' "$cap")"
    if [[ -z "${name//[[:space:]]/}" ]]; then
      report error "$ZIP" "commerce-app.json \"name\" is blank; the platform ignores it"
    elif [[ "$(printf '%s' "$name" | wc -c)" -gt 256 ]]; then
      report error "$ZIP" "commerce-app.json \"name\" exceeds 256 bytes; the platform ignores it"
    fi
  fi
fi

# --- root manifest must agree with the directory domain (both the array key and the entry's domain field) ---
if [[ -f "$ROOT_MANIFEST" ]]; then
  while IFS=$'\t' read -r m_key m_domain; do
    [[ -z "$m_key" ]] && continue
    if [[ "$m_key" != "$domain" ]]; then
      report error "$ZIP" "Root manifest lists \"$app_id\" under \"$m_key\" but the ZIP is in directory domain \"$domain\""
    fi
    if [[ "$m_domain" != "$domain" ]]; then
      report error "$ZIP" "Root manifest entry for \"$app_id\" has domain \"$m_domain\" but the ZIP is in directory domain \"$domain\""
    fi
  done < <(jq -r --arg id "$app_id" 'to_entries[] | select(.value | type == "array") | .key as $k | .value[] | select(.id == $id) | [$k, (.domain // "")] | @tsv' "$ROOT_MANIFEST")
fi

enforce="$(jq -r --arg d "$domain" '.domains[$d].enforce // "none"' "$CONFIG")"
base="$(find "$tmpdir" -type d -path '*/cartridges/site_cartridges' -print -quit)"
hooks_file=""
pointer_problem=""
# The platform finds hooks through each site cartridge's package.json "hooks" entry, not by
# scanning for hooks.json. Resolve the file exactly the way the platform does.
if [[ -n "$base" ]]; then
  for pkg in "$base"/*/package.json; do
    [[ -f "$pkg" ]] || continue
    ptr="$(jq -r 'if (.hooks | type) == "string" then .hooks else empty end' "$pkg" 2>/dev/null || true)"
    [[ -z "$ptr" ]] && continue
    cart_dir="$(dirname "$pkg")"
    cart_name="$(basename "$cart_dir")"
    if [[ "$ptr" == /* || "/$ptr/" == *"/../"* ]]; then
      pointer_problem="$cart_name/package.json \"hooks\" ($ptr) must be a path inside the cartridge"
    elif [[ ! -f "$cart_dir/$ptr" ]]; then
      pointer_problem="$cart_name/package.json \"hooks\" points to $ptr, which does not exist"
    elif ! jq -e '.hooks | type == "array"' "$cart_dir/$ptr" > /dev/null 2>&1; then
      pointer_problem="$cart_name/package.json \"hooks\" points to $ptr, which has no \"hooks\" array"
    else
      hooks_file="$cart_dir/$ptr"
      pointer_problem=""
      break
    fi
  done
  if [[ -z "$hooks_file" && -z "$pointer_problem" ]]; then
    if [[ -n "$(find "$base" -type f -name hooks.json -print -quit)" ]]; then
      pointer_problem="a hooks.json exists but no site cartridge package.json has a \"hooks\" entry pointing to it, so the platform will not register any hooks"
    fi
  fi
fi

# Hooks of the form sfcc.app.<x>.* with x != domain are never valid (domain consistency).
if [[ -n "$hooks_file" ]]; then
  while IFS= read -r name; do
    [[ "$name" == sfcc.app.* && "$name" != "sfcc.app.${domain}."* ]] || continue
    other="$(cut -d. -f3 <<< "$name")"
    # Flag hooks that belong to another known domain, and any mis-domained health hook
    # (the platform fails the install on the latter).
    if jq -e --arg o "$other" '.domains | has($o)' "$CONFIG" > /dev/null || [[ "$name" == *.checkConnectionHealth ]]; then
      report error "$ZIP" "Hook \"$name\" is not in this app's domain \"$domain\" (expected sfcc.app.${domain}.*)"
    fi
  done < <(jq -r '.hooks[]?.name // empty' "$hooks_file")

  # Warn on any hook that is not a commerce-app extension point. This does not
  # fail the build. Domains with a strict allow-list still error below.
  while IFS= read -r name; do
    [[ "$name" == sfcc.app.* ]] && continue
    report warning "$ZIP" "Hook \"$name\" is not an app-specific hook. If possible, use app-specific hooks which start with sfcc.app.*"
  done < <(jq -r '.hooks[]?.name // empty' "$hooks_file")
fi

if [[ "$enforce" == "none" ]]; then
  echo "No hook rules for domain \"$domain\"; skipping required-hook checks for $ZIP"
  [[ "$ERRORS" -eq 0 ]]; exit $?
fi
LEVEL="$enforce"; [[ "$LEVEL" == "warn" ]] && LEVEL="warning"

# --- Salesforce-native apps ship no cartridge code; the platform implements the hooks ---
if [[ -z "$hooks_file" ]]; then
  provider="$(jq -r --arg d "$domain" --arg id "$app_id" '.[$d][]? | select(.id == $id) | .provider // empty' "$ROOT_MANIFEST" 2>/dev/null | head -n 1)"
  if [[ -z "$base" && "$provider" == "salesforce" ]]; then
    echo "Skipping hook checks for $ZIP: Salesforce-native app without site cartridges"
    [[ "$ERRORS" -eq 0 ]]; exit $?
  fi
  if [[ -n "$pointer_problem" ]]; then
    violation "Hooks are not registered: $pointer_problem"
  else
    violation "No hooks registered: no site cartridge package.json has a \"hooks\" entry; $domain apps must register their extension points"
  fi
  [[ "$ERRORS" -eq 0 ]]; exit $?
fi
hooks_dir="$(dirname "$hooks_file")"
echo "ZIP: $ZIP (domain=$domain, enforce=$enforce)"

required=(); while IFS= read -r s; do required+=("$s"); done < <(jq -r --arg d "$domain" '.domains[$d].required[]?' "$CONFIG")
any_of=();   while IFS= read -r s; do any_of+=("$s");   done < <(jq -r --arg d "$domain" '.domains[$d].requiredAnyOf[]?' "$CONFIG")
optional=(); while IFS= read -r s; do optional+=("$s"); done < <(jq -r --arg d "$domain" '.domains[$d].optional[]?, .universalOptional[]?' "$CONFIG")
strict="$(jq -r --arg d "$domain" '.domains[$d].strictAllowList // false' "$CONFIG")"

script_for() { jq -r --arg n "sfcc.app.${domain}.$1" '.hooks[]? | select(.name == $n) | .script // empty' "$hooks_file" | head -n 1; }

check_script() { # $1 = suffix; verifies script exists, exports the function, and domain rules
  local suffix="$1" script target
  script="$(script_for "$suffix")"
  [[ -z "$script" ]] && return 0
  target="$hooks_dir/${script#./}"
  [[ -f "$target" || -f "$target.js" ]] || { violation "Script for \"sfcc.app.${domain}.${suffix}\" points to missing file: $script"; return 0; }
  [[ -f "$target" ]] || target="$target.js"
  # The platform calls the export named after the last hook-name segment.
  if ! grep -qE "\b${suffix}\b" "$target"; then
    violation "Script $script does not define/export a function named \"${suffix}\" (the platform calls the hook by that name)"
  fi
  if [[ "$domain" == "payment" ]] && grep -q 'COMMERCE_APP_GIFT_CARD' "$target"; then
    violation "Script $script references COMMERCE_APP_GIFT_CARD; that payment method ID is reserved and cannot be claimed by a payment app"
  fi
  if [[ "$domain" == "fraud" && "$suffix" == "afterPayment" ]] && grep -qE '\bOrderMgr\b' "$target"; then
    violation "afterPayment script $script uses OrderMgr; the hook must return a Status and must not change the order directly"
  fi
}

registered=()
while IFS= read -r name; do registered+=("$name"); done < <(jq -r '.hooks[]?.name // empty' "$hooks_file")

for suffix in ${required[@]+"${required[@]}"}; do
  [[ -n "$(script_for "$suffix")" ]] || violation "Missing required hook \"sfcc.app.${domain}.${suffix}\""
done
if [[ ${#any_of[@]} -gt 0 ]]; then
  found=false
  for suffix in "${any_of[@]}"; do [[ -n "$(script_for "$suffix")" ]] && found=true; done
  [[ "$found" == "true" ]] || violation "Register at least one of: $(printf 'sfcc.app.%s.%s ' "$domain" "${any_of[@]}")"
fi

known=(${required[@]+"${required[@]}"} ${any_of[@]+"${any_of[@]}"} ${optional[@]+"${optional[@]}"})
for name in ${registered[@]+"${registered[@]}"}; do
  suffix="${name#sfcc.app.${domain}.}"
  if [[ "$name" == "sfcc.app.${domain}."* ]]; then
    ok=false
    for k in ${known[@]+"${known[@]}"}; do [[ "$k" == "$suffix" ]] && ok=true && break; done
    if [[ "$ok" == "false" ]]; then
      violation "Unknown hook \"$name\". Valid ${domain} hooks: ${known[*]}"
      continue
    fi
    check_script "$suffix"
  elif [[ "$name" != sfcc.app.* && "$strict" == "true" ]]; then
    violation "Disallowed hook \"$name\". Only sfcc.app.${domain}.* hooks are allowed for $domain apps"
  fi
done

if [[ "$ERRORS" -eq 0 ]]; then
  echo "Hook checks passed for $ZIP"
fi
[[ "$ERRORS" -eq 0 ]]

